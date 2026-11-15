using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

// All manifests, authorizations and text in these fixtures are invented test data.
public sealed class ReleasedRetrievalTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "nutrition-r4-synthetic-" + Guid.NewGuid().ToString("N"));
    private static readonly MealKnowledgeRequest Query = new(["robot"], [], [], "", "");

    public ReleasedRetrievalTests()
    {
        Directory.CreateDirectory(_directory);
        foreach (var file in Directory.GetFiles(Path.Combine(AppContext.BaseDirectory, "Fixtures", "ReleasedRetrieval")))
            File.Copy(file, Path.Combine(_directory, Path.GetFileName(file)));
    }

    [Fact]
    public void Keyword_matches_python_ids_and_order_for_every_synthetic_question()
    {
        using var cases = JsonDocument.Parse(File.ReadAllBytes(FilePath("cases.json")));
        using var expected = JsonDocument.Parse(File.ReadAllBytes(FilePath("expected.json")));
        var index = new KeywordMealKnowledgeIndex(File.ReadAllBytes(FilePath("corpus.jsonl")));
        var rows = expected.RootElement.EnumerateArray().ToDictionary(x => x.GetProperty("case_id").GetString()!);
        foreach (var item in cases.RootElement.EnumerateArray())
        {
            var id = item.GetProperty("case_id").GetString()!;
            var guard = item.TryGetProperty("edition_guard", out var edition) && edition.GetBoolean();
            var filter = item.TryGetProperty("filter_revision", out var filtered) && filtered.GetBoolean();
            var actual = index.Search(item.GetProperty("question").GetString()!,
                item.TryGetProperty("top_k", out var top) ? top.GetInt32() : 5,
                item.TryGetProperty("minimum_score", out var minimum) ? minimum.GetDouble() : 0,
                guard || filter ? item.GetProperty("source_revision_id").GetString() : null, guard);
            Assert.Equal(rows[id].GetProperty("chunk_ids").EnumerateArray().Select(x => x.GetString()), actual.Select(x => x.Id));
        }
    }

    [Theory]
    [InlineData("keyword")]
    [InlineData("graph")]
    public async Task Python_authorized_release_returns_citations_and_ready(string strategy)
    {
        var options = Options.Create(Settings(strategy));
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(options, new TestEnvironment("Staging"));
        var result = await retriever.RetrieveAsync(Query, CancellationToken.None);
        Assert.True(result.Available);
        Assert.Equal(strategy, result.Strategy);
        Assert.NotEmpty(result.Evidence);
        Assert.Empty(result.Warnings);
        var ready = await MealGroundingReadiness.CheckAsync(options, retriever, CancellationToken.None);
        Assert.True(ready.Available);
        Assert.Equal("available", ready.Status);
    }

    [Theory]
    [InlineData("vector")]
    [InlineData("hybrid")]
    public async Task Embedding_strategies_are_explicitly_unavailable(string strategy)
    {
        var options = Options.Create(Settings(strategy));
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(options, new TestEnvironment("Staging"));
        var result = await retriever.RetrieveAsync(Query, CancellationToken.None);
        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Equal(["strategy_requires_embedding_runtime"], result.Warnings);
        Assert.False((await MealGroundingReadiness.CheckAsync(options, retriever, CancellationToken.None)).Available);
    }

    [Theory]
    [InlineData("missing_authorization")]
    [InlineData("wrong_manifest_hash")]
    [InlineData("wrong_authorization_hash")]
    [InlineData("wrong_environment")]
    [InlineData("development")]
    [InlineData("authorization_strategy")]
    [InlineData("authorization_manifest")]
    [InlineData("missing_signer")]
    [InlineData("missing_comment")]
    [InlineData("invalid_timestamp")]
    [InlineData("invalid_role")]
    [InlineData("tampered_authorization")]
    [InlineData("tampered_manifest")]
    [InlineData("invalid_manifest_json")]
    [InlineData("invalid_manifest_type")]
    [InlineData("release_not_ready")]
    [InlineData("gate_failure")]
    [InlineData("selected_gate_failure")]
    [InlineData("missing_holdout")]
    [InlineData("corpus_binding")]
    [InlineData("tampered_corpus")]
    [InlineData("config_binding")]
    [InlineData("invalid_threshold")]
    public async Task Invalid_release_is_unavailable_and_readiness_explains_fallback(string failure)
    {
        switch (failure)
        {
            case "authorization_strategy": Mutate("authorization-keyword.json", x => x["selected_strategy"] = "graph"); break;
            case "authorization_manifest": Mutate("authorization-keyword.json", x => x["manifest_sha256"] = new string('0', 64)); break;
            case "missing_signer": Mutate("authorization-keyword.json", x => x.AsObject().Remove("reviewer_id")); break;
            case "missing_comment": Mutate("authorization-keyword.json", x => x["comment"] = " "); break;
            case "invalid_timestamp": Mutate("authorization-keyword.json", x => x["timestamp"] = "2026-11-10"); break;
            case "invalid_role": Mutate("authorization-keyword.json", x => x["role"] = "developer"); break;
            case "tampered_authorization": Mutate("authorization-keyword.json", x => x["comment"] = "tampered", sign: false); break;
            case "tampered_manifest": Mutate("manifest-keyword.json", x => x["release_ready"] = false, sign: false); break;
            case "invalid_manifest_json": File.WriteAllText(FilePath("manifest-keyword.json"), "{"); break;
            case "invalid_manifest_type": File.WriteAllText(FilePath("manifest-keyword.json"), "[]"); break;
            case "release_not_ready": MutateManifest(x => x["release_ready"] = false); break;
            case "gate_failure": MutateManifest(x => x["gate_failures"] = new JsonArray("pending")); break;
            case "selected_gate_failure": MutateManifest(x => x["strategy_gate_failures"]!["keyword"] = new JsonArray("failed")); break;
            case "missing_holdout": MutateManifest(x => x.AsObject().Remove("holdout_report_sha256")); break;
            case "corpus_binding": MutateManifest(x => x["bindings"]!["corpus_freeze_sha256"] = new string('0', 64)); break;
            case "tampered_corpus": File.AppendAllText(FilePath("corpus.jsonl"), "{}"); break;
            case "config_binding": MutateManifest(x => x["bindings"]!["config"]!["keyword_minimum_score"] = 1); break;
            case "invalid_threshold": MutateManifest(x => {
                x["bindings"]!["config"]!["keyword_minimum_score"] = -1;
                using var json = JsonDocument.Parse(x["bindings"]!["config"]!.ToJsonString());
                x["bindings"]!["config_sha256"] = RuntimeReleaseArtifact.ContentHash(json.RootElement);
            }); break;
        }
        var options = Options.Create(Settings(failure: failure));
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(options,
            new TestEnvironment(failure == "wrong_environment" ? "Production" : failure == "development" ? "Development" : "Staging"));
        var result = await retriever.RetrieveAsync(Query, CancellationToken.None);
        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Equal(["grounding_release_invalid"], result.Warnings);
        var readiness = await MealGroundingReadiness.CheckAsync(options, retriever, CancellationToken.None);
        Assert.False(readiness.Available);
        Assert.Equal("grounding unavailable", readiness.Status);
    }

    [Fact]
    public async Task Revocation_is_observed_on_next_request()
    {
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"));
        Assert.True((await retriever.RetrieveAsync(Query, CancellationToken.None)).Available);
        File.Delete(FilePath("authorization-keyword.json"));
        Assert.False((await retriever.RetrieveAsync(Query, CancellationToken.None)).Available);
    }

    [Theory]
    [InlineData("graph_binding")]
    [InlineData("freeze_binding")]
    [InlineData("candidate_mode")]
    [InlineData("dangling_edge")]
    public async Task Released_graph_strategy_rejects_unbound_or_invalid_graph(string failure)
    {
        Mutate("graph.json", x =>
        {
            if (failure == "freeze_binding") x["corpus_freeze_sha256"] = new string('0', 64);
            if (failure == "candidate_mode") x["mode"] = "retrieval_graph_candidate";
            if (failure == "dangling_edge") x["edges"]![0]!["to"] = "missing-node";
        });
        if (failure != "graph_binding")
        {
            using var graph = JsonDocument.Parse(File.ReadAllBytes(FilePath("graph.json")));
            var graphHash = graph.RootElement.GetProperty("content_sha256").GetString();
            Mutate("manifest-graph.json", x => x["bindings"]!["graph_sha256"] = graphHash);
            Mutate("authorization-graph.json", x => x["manifest_sha256"] = Hash("manifest-graph.json").ToLowerInvariant());
        }
        else
            Mutate("graph.json", x => x["nodes"]![0]!["label"] = "altered robot");
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings("graph")), new TestEnvironment("Staging"));
        Assert.False((await retriever.RetrieveAsync(Query, CancellationToken.None)).Available);
    }

    [Fact]
    public async Task Missing_authorization_preserves_rule_baseline_and_constraints()
    {
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings(failure: "missing_authorization")), new TestEnvironment("Staging"));
        Recipe MakeRecipe(string mealType) => new(Guid.NewGuid(), $"Synthetic {mealType}", mealType, 1,
            [new("RICE", "Synthetic rice", 100, "g", "raw")], [],
            new() { ["energy_kcal"] = 100, ["sodium_mg"] = 10 }, ["Synthetic step"], ["Synthetic"], true);
        var recipes = new[] { MakeRecipe("breakfast"), MakeRecipe("lunch"), MakeRecipe("dinner") };
        var result = await new MealRecommendationEngine(retriever, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(7, recipes, [], [], "regular", "maintain"), CancellationToken.None);
        Assert.NotNull(result.Meals);
        Assert.Equal(recipes.Select(x => x.VersionId), result.Meals!.Select(x => x.VersionId));
        Assert.Equal("rule_baseline", result.Trace.Strategy);
        Assert.False(result.Trace.UsedAi);
        Assert.Empty(result.Trace.Evidence);
        Assert.Contains("grounding_release_invalid", result.Trace.Warnings);
        Assert.True(MealConstraintPolicy.Matches(result.Meals, [], []));
    }

    [Fact]
    public async Task Unmatched_and_empty_queries_abstain_without_becoming_unavailable()
    {
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"));
        foreach (var question in new[] { "", "unmatchedword" })
        {
            var result = await retriever.RetrieveAsync(new([question], [], [], "", ""), CancellationToken.None);
            Assert.True(result.Available);
            Assert.Empty(result.Evidence);
            Assert.Contains(question.Length == 0 ? "grounding_query_empty" : "grounding_insufficient_evidence", result.Warnings);
        }
        using var cts = new CancellationTokenSource();
        cts.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => retriever.RetrieveAsync(Query, cts.Token));
    }

    [Fact]
    public async Task Missing_release_artifacts_keep_host_live_and_readiness_reports_grounding_unavailable()
    {
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(web =>
        {
            web.UseEnvironment("Staging");
            web.UseSetting("Jwt:SecretKey", new string('s', 64));
            web.UseSetting("Jwt:Issuer", "synthetic-r4-issuer");
            web.UseSetting("Jwt:Audience", "synthetic-r4-audience");
            web.UseSetting("People:BaseUrl", "https://people.example.test/");
            web.UseSetting("People:ServiceKey", new string('p', 64));
            web.UseSetting("ConnectionStrings:Nutrition", "Host=127.0.0.1;Port=1;Database=unused;Username=unused;Timeout=1");
            web.UseSetting("MealGrounding:Enabled", "true");
            web.UseSetting("MealGrounding:Mode", "released_retrieval");
            web.UseSetting("MealGrounding:ManifestPath", "missing.json");
            web.UseSetting("MealGrounding:ManifestSha256", "bad");
        });
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/live")).StatusCode);
        var response = await client.GetAsync("/health/ready");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Contains("grounding unavailable", await response.Content.ReadAsStringAsync());
    }

    private void UseReferencePolicy(string strategy)
    {
        void Policy(JsonNode x)
        {
            x["review_policy"] = "non_medical_reference";
            x["clinical_review_performed"] = false;
            x["independent_clinical_review"] = false;
            x["intended_use"] = "academic_reference_non_medical";
            x["production_public_release"] = false;
            x["clinical_review_not_performed_reason"] = "no_clinical_reviewer_non_medical_reference";
        }
        Mutate("graph.json", Policy);
        using var graph = JsonDocument.Parse(File.ReadAllBytes(FilePath("graph.json")));
        Mutate($"manifest-{strategy}.json", x =>
        {
            Policy(x);
            x["bindings"]!["graph_sha256"] = graph.RootElement.GetProperty("content_sha256").GetString();
        });
        Mutate($"authorization-{strategy}.json", x =>
        {
            Policy(x);
            x["manifest_sha256"] = Hash($"manifest-{strategy}.json").ToLowerInvariant();
        });
    }

    [Theory]
    [InlineData("keyword", false, false)]
    [InlineData("keyword", true, false)]
    [InlineData("graph", false, false)]
    [InlineData("graph", true, false)]
    [InlineData("graph", false, true)]
    [InlineData("graph", true, true)]
    public async Task Reference_policy_requires_option_and_propagates_reference_status(string strategy, bool allow, bool graphMode)
    {
        UseReferencePolicy(strategy);
        var settings = Settings(strategy, allowReference: allow, graphMode: graphMode);
        IMealKnowledgeRetriever retriever = graphMode
            ? new ReleasedGraphMealKnowledgeRetriever(Options.Create(settings), new TestEnvironment("Staging"))
            : new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(settings), new TestEnvironment("Staging"));
        var result = await retriever.RetrieveAsync(Query, CancellationToken.None);
        var ready = await MealGroundingReadiness.CheckAsync(Options.Create(settings), retriever, CancellationToken.None);
        Assert.Equal(allow, result.Available);
        Assert.Equal(allow, ready.Available);
        if (!allow)
        {
            Assert.Contains(ReleaseReviewPolicy.NotAllowed, result.Warnings);
            Assert.Contains(ReleaseReviewPolicy.NotAllowed, ready.Reasons);
            return;
        }
        Assert.Equal("reference", result.ReleaseStatus);
        Assert.Equal("non_medical_reference", result.ReviewPolicy);
        Assert.Equal("academic_reference_non_medical", result.IntendedUse);
        Recipe Recipe(string meal) => new(Guid.NewGuid(), "Synthetic " + meal, meal, 1,
            [new("ROBOT", "robot", 100, "g", "raw")], [], new() { ["energy_kcal"] = 100 }, ["Synthetic"], ["Synthetic"], true);
        var output = await new MealRecommendationEngine(retriever, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(1, [Recipe("breakfast"), Recipe("lunch"), Recipe("dinner")], [], [], "regular", "maintain"), CancellationToken.None);
        Assert.Equal("reference", output.Trace.ReleaseStatus);
        using var json = JsonDocument.Parse(NutritionJson.Write(output.Trace));
        Assert.Equal("reference", json.RootElement.GetProperty("releaseStatus").GetString());
    }

    [Theory]
    [InlineData("missing_policy")]
    [InlineData("missing_intent")]
    [InlineData("unknown_policy")]
    [InlineData("wrong_type")]
    [InlineData("clinical_claim")]
    [InlineData("independent_claim")]
    [InlineData("public_claim")]
    [InlineData("missing_reason")]
    [InlineData("authorization_policy")]
    [InlineData("dietitian")]
    [InlineData("physician")]
    [InlineData("tampered_policy")]
    [InlineData("graph_policy")]
    public async Task Policy_metadata_fails_closed_even_with_pinned_file_hash(string failure)
    {
        var strategy = failure == "graph_policy" ? "graph" : "keyword";
        UseReferencePolicy(strategy);
        if (failure == "graph_policy")
        {
            Mutate("graph.json", x => x.AsObject().Remove("review_policy"));
            using var graph = JsonDocument.Parse(File.ReadAllBytes(FilePath("graph.json")));
            Mutate("manifest-graph.json", x => x["bindings"]!["graph_sha256"] = graph.RootElement.GetProperty("content_sha256").GetString());
        }
        else if (failure is "authorization_policy" or "dietitian" or "physician")
            Mutate("authorization-keyword.json", x => x[failure == "authorization_policy" ? "review_policy" : "role"] =
                failure == "authorization_policy" ? "source_and_clinical" : failure);
        else
            Mutate($"manifest-{strategy}.json", x =>
            {
                switch (failure)
                {
                    case "missing_policy": x.AsObject().Remove("review_policy"); break;
                    case "missing_intent": x.AsObject().Remove("intended_use"); break;
                    case "unknown_policy": x["review_policy"] = "unknown"; break;
                    case "wrong_type": x["clinical_review_performed"] = "false"; break;
                    case "clinical_claim": x["clinical_review_performed"] = true; break;
                    case "independent_claim": x["independent_clinical_review"] = true; break;
                    case "public_claim": x["production_public_release"] = true; break;
                    case "missing_reason": x.AsObject().Remove("clinical_review_not_performed_reason"); break;
                    case "tampered_policy": x["review_policy"] = "source_and_clinical"; break;
                }
            }, sign: failure != "tampered_policy");
        Mutate($"authorization-{strategy}.json", x => x["manifest_sha256"] = Hash($"manifest-{strategy}.json").ToLowerInvariant());
        var result = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings(strategy, allowReference: true)),
            new TestEnvironment("Staging")).RetrieveAsync(Query, CancellationToken.None);
        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Contains("grounding_release_invalid", result.Warnings);
    }

    [Fact]
    public async Task Clinical_policy_retains_released_status()
    {
        var result = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        Assert.Equal("released", result.ReleaseStatus);
        Assert.False(new MealGroundingOptions().AllowNonMedicalReference);
    }

    // R5: synthetic explanation index built from the pinned reviewed graph fixture (metadata only).
    private async Task<MealGroundingOptions> WithExplanationIndex(string? failure = null)
    {
        var plain = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        using var graph = JsonDocument.Parse(File.ReadAllBytes(FilePath("graph.json")));
        using var freeze = JsonDocument.Parse(File.ReadAllBytes(FilePath("freeze.json")));
        var chunks = new JsonObject();
        foreach (var item in plain.Evidence)
            chunks[item.Id] = new JsonObject
            {
                ["graphPath"] = new JsonArray(
                    new JsonObject { ["node_id"] = "topic:synthetic", ["heading"] = "Synthetic heading", ["pages"] = new JsonArray(3, 4) },
                    new JsonObject { ["node_id"] = "chunk:" + item.Id, ["heading"] = null, ["pages"] = new JsonArray(4) })
            };
        var index = new JsonObject
        {
            ["schema_version"] = 1,
            ["mode"] = failure == "candidate_mode" ? "retrieval_graph_candidate" : MealGraphExplanationIndex.Mode,
            ["review_policy"] = failure == "wrong_policy" ? "non_medical_reference" : "source_and_clinical",
            ["bindings"] = new JsonObject
            {
                ["graph_sha256"] = failure == "wrong_graph" ? new string('e', 64) : graph.RootElement.GetProperty("content_sha256").GetString(),
                ["candidate_sha256"] = new string('c', 64),
                ["ledger_sha256"] = new string('d', 64),
                ["corpus_sha256"] = failure == "wrong_corpus" ? new string('f', 64) : Hash("corpus.jsonl").ToLowerInvariant(),
                ["corpus_freeze_sha256"] = freeze.RootElement.GetProperty("content_sha256").GetString()
            },
            ["chunks"] = chunks
        };
        File.WriteAllText(FilePath("explanation.json"), index.ToJsonString());
        Mutate("explanation.json", _ => { }, sign: failure != "tampered");
        return Settings(explanationPath: failure == "missing" ? FilePath("missing-explanation.json") : FilePath("explanation.json"),
            explanationHash: failure == "wrong_pin" ? new string('0', 64) : Hash("explanation.json"));
    }

    [Fact]
    public async Task Keyword_release_uses_reviewed_graph_only_to_explain_citations()
    {
        var settings = await WithExplanationIndex();
        var retriever = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(settings), new TestEnvironment("Staging"));
        var result = await retriever.RetrieveAsync(Query, CancellationToken.None);
        var plain = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        Assert.Equal("explanation", result.GraphRole);
        Assert.Equal(plain.Evidence.Select(x => x.Id), result.Evidence.Select(x => x.Id));
        Assert.All(result.Evidence, item => Assert.Equal("topic:synthetic", item.GraphPath[0].NodeId));

        var output = await new MealRecommendationEngine(retriever, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(1, [SyntheticRecipe("breakfast"), SyntheticRecipe("lunch"), SyntheticRecipe("dinner")], [], [], "regular", "maintain"), CancellationToken.None);
        Assert.Equal("released", output.Trace.ReleaseStatus);
        Assert.Equal("keyword", output.Trace.RetrievalStrategy);
        Assert.Equal("explanation", output.Trace.GraphRole);
        Assert.Equal(NutritionDisclaimer.Reviewed, output.Trace.Disclaimer);
        var json = NutritionJson.Write(output.Trace);
        using var parsed = JsonDocument.Parse(json);
        var citation = parsed.RootElement.GetProperty("citations")[0];
        Assert.Equal("Synthetic heading", citation.GetProperty("graphPath")[0].GetProperty("heading").GetString());
        Assert.False(citation.TryGetProperty("excerpt", out _));
        foreach (var line in File.ReadLines(FilePath("corpus.jsonl")).Where(x => x.Length > 0))
        {
            using var chunk = JsonDocument.Parse(line);
            if (chunk.RootElement.TryGetProperty("text", out var text) && text.GetString() is { Length: > 20 } body)
                Assert.DoesNotContain(body, json);
        }
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("wrong_pin")]
    [InlineData("tampered")]
    [InlineData("candidate_mode")]
    [InlineData("wrong_policy")]
    [InlineData("wrong_graph")]
    [InlineData("wrong_corpus")]
    public async Task Invalid_explanation_index_keeps_citations_and_drops_graph_path(string failure)
    {
        var settings = await WithExplanationIndex(failure);
        var result = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(settings), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        Assert.True(result.Available);
        Assert.NotEmpty(result.Evidence);
        Assert.Equal("none", result.GraphRole);
        Assert.All(result.Evidence, item => Assert.Empty(item.GraphPath));
    }

    [Fact]
    public async Task Graph_strategy_is_the_only_retrieval_graph_role()
    {
        var graph = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings("graph")), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        var keyword = await new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings()), new TestEnvironment("Staging"))
            .RetrieveAsync(Query, CancellationToken.None);
        Assert.Equal("retrieval", graph.GraphRole);
        Assert.Equal("none", keyword.GraphRole);
    }

    [Fact]
    public async Task Release_status_and_disclaimer_follow_backend_policy_without_forbidden_claims()
    {
        UseReferencePolicy("keyword");
        var reference = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings(allowReference: true)), new TestEnvironment("Staging"));
        var meals = new[] { SyntheticRecipe("breakfast"), SyntheticRecipe("lunch"), SyntheticRecipe("dinner") };
        var referenceTrace = (await new MealRecommendationEngine(reference, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(1, meals, [], [], "regular", "maintain"), CancellationToken.None)).Trace;
        Assert.Equal("reference", referenceTrace.ReleaseStatus);
        Assert.Equal(NutritionDisclaimer.Reference, referenceTrace.Disclaimer);
        Assert.Equal(NutritionDisclaimer.ReferenceVersion, referenceTrace.DisclaimerVersion);

        var demoMeals = meals.Select(x => x with { Name = "[DEMO] " + x.Name }).ToArray();
        var demoTrace = (await new MealRecommendationEngine(reference, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(1, demoMeals, [], [], "regular", "maintain"), CancellationToken.None)).Trace;
        Assert.Equal("demo", demoTrace.ReleaseStatus);
        Assert.Equal("none", demoTrace.GraphRole);
        Assert.Null(demoTrace.RetrievalStrategy);
        Assert.Equal(NutritionDisclaimer.Reference, demoTrace.Disclaimer);

        var unavailable = new ReleasedRetrievalMealKnowledgeRetriever(Options.Create(Settings(failure: "missing_authorization")), new TestEnvironment("Staging"));
        var ungrounded = (await new MealRecommendationEngine(unavailable, new UnavailableMealCandidateRanker())
            .RecommendAsync(new(1, meals, [], [], "regular", "maintain"), CancellationToken.None)).Trace;
        Assert.Equal("ungrounded", ungrounded.ReleaseStatus);
        Assert.Empty(ungrounded.Citations);

        foreach (var text in new[] { NutritionDisclaimer.Reference, NutritionDisclaimer.Reviewed })
            foreach (var forbidden in new[] { "điều trị", "chữa", "đã được chuyên gia" })
                Assert.DoesNotContain(forbidden, text, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("chưa được chuyên gia", NutritionDisclaimer.Reviewed);
    }

    [Fact]
    public void Old_trace_without_release_fields_reads_as_demo()
    {
        var trace = NutritionJson.Read<MealRecommendationTrace>(
            """{"schemaVersion":2,"strategy":"graph_grounded_rule","usedAi":false,"evidence":[],"explanations":[],"warnings":[],"groundingStrategy":"graph_seed_rrf"}""");
        Assert.Equal("demo", trace.ReleaseStatus);
        Assert.Equal("none", trace.GraphRole);
        Assert.Equal(NutritionDisclaimer.ReferenceVersion, trace.DisclaimerVersion);
    }

    private static Recipe SyntheticRecipe(string meal) => new(Guid.NewGuid(), "Synthetic " + meal, meal, 1,
        [new("ROBOT", "robot", 100, "g", "raw")], [], new() { ["energy_kcal"] = 100 }, ["Synthetic"], ["Synthetic"], true);

    private MealGroundingOptions Settings(string strategy = "keyword", string? failure = null, bool allowReference = false, bool graphMode = false,
        string explanationPath = "", string explanationHash = "") => new()
    {
        ExplanationIndexPath = explanationPath, ExplanationIndexSha256 = explanationHash,
        Enabled = true, Mode = graphMode ? MealGroundingOptions.ReleasedGraphMode : MealGroundingOptions.ReleasedRetrievalMode,
        AllowNonMedicalReference = allowReference,
        ManifestPath = FilePath($"manifest-{strategy}.json"), ManifestSha256 = failure == "wrong_manifest_hash" ? new string('0', 64) : Hash($"manifest-{strategy}.json"),
        RuntimeAuthorizationPath = failure == "missing_authorization" ? FilePath("missing.json") : FilePath($"authorization-{strategy}.json"),
        RuntimeAuthorizationSha256 = failure == "wrong_authorization_hash" ? new string('0', 64) : Hash($"authorization-{strategy}.json"),
        CorpusPath = FilePath("corpus.jsonl"), CorpusSha256 = Hash("corpus.jsonl"),
        CorpusFreezePath = FilePath("freeze.json"), CorpusFreezeSha256 = Hash("freeze.json"),
        ReviewedGraphPath = FilePath("graph.json"), ReviewedGraphSha256 = Hash("graph.json")
    };

    private void MutateManifest(Action<JsonNode> mutation)
    {
        Mutate("manifest-keyword.json", mutation);
        Mutate("authorization-keyword.json", x => x["manifest_sha256"] = Hash("manifest-keyword.json").ToLowerInvariant());
    }

    private void Mutate(string file, Action<JsonNode> mutation, bool sign = true)
    {
        var root = JsonNode.Parse(File.ReadAllText(FilePath(file)))!;
        mutation(root);
        if (sign)
        {
            using var json = JsonDocument.Parse(root.ToJsonString());
            root["content_sha256"] = RuntimeReleaseArtifact.ContentHash(json.RootElement, "content_sha256");
        }
        File.WriteAllText(FilePath(file), root.ToJsonString());
    }

    private string FilePath(string name) => Path.Combine(_directory, name);
    private string Hash(string name) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(FilePath(name))));
    public void Dispose() => Directory.Delete(_directory, true);
    private sealed class TestEnvironment(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "CareSitter.Nutrition.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
