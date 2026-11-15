using System.Globalization;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class ReleasedRetrievalMealKnowledgeRetriever(
    IOptions<MealGroundingOptions> options, IHostEnvironment environment) : IMealKnowledgeRetriever
{
    // Revalidate on every request: revocation, changed files and readiness share one trust boundary.
    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var settings = options.Value;
        try
        {
            using var manifest = JsonDocument.Parse(GroundingArtifact.ReadVerified(settings.ManifestPath, settings.ManifestSha256));
            var root = manifest.RootElement;
            RuntimeReleaseArtifact.Verify(root, "retrieval_release_manifest");
            var reviewPolicy = ReleaseReviewPolicy.Read(root);
            var strategy = root.GetProperty("selected_strategy").GetString() ?? "";
            if (!root.GetProperty("release_ready").GetBoolean() || root.GetProperty("gate_failures").GetArrayLength() != 0 ||
                root.GetProperty("decision").GetString() != "simplest_strategy_passing_all_gates" ||
                strategy is not ("keyword" or "graph" or "vector" or "hybrid") ||
                root.GetProperty("strategy_gate_failures").GetProperty(strategy).GetArrayLength() != 0)
                throw new InvalidOperationException("Release gates are not satisfied.");
            foreach (var field in new[] { "benchmark_freeze_sha256", "holdout_report_sha256", "holdout_review_sha256" })
                if (!RuntimeReleaseArtifact.IsDigest(root.GetProperty(field).GetString()))
                    throw new InvalidOperationException("Missing holdout evidence binding.");
            using var authorization = JsonDocument.Parse(GroundingArtifact.ReadVerified(
                settings.RuntimeAuthorizationPath, settings.RuntimeAuthorizationSha256));
            ValidateAuthorization(authorization.RootElement, settings.ManifestSha256, strategy, environment.EnvironmentName, reviewPolicy);
            if (reviewPolicy == ReleaseReviewPolicy.Reference && !settings.AllowNonMedicalReference)
                return Task.FromResult(MealKnowledgeResult.Unavailable(ReleaseReviewPolicy.NotAllowed));
            if (settings.Mode == MealGroundingOptions.ReleasedGraphMode && strategy != "graph")
                throw new InvalidOperationException("Graph mode requires a graph release.");
            if (strategy is "vector" or "hybrid")
                return Task.FromResult(MealKnowledgeResult.Unavailable("strategy_requires_embedding_runtime"));

            var bindings = root.GetProperty("bindings");
            using var freeze = JsonDocument.Parse(GroundingArtifact.ReadVerified(settings.CorpusFreezePath, settings.CorpusFreezeSha256));
            RuntimeReleaseArtifact.Verify(freeze.RootElement, "local_retrieval_corpus_freeze", excludeTimestamp: true);
            var revision = freeze.RootElement.GetProperty("content_sha256").GetString()!;
            if (!RuntimeReleaseArtifact.Equal(bindings.GetProperty("corpus_freeze_sha256").GetString(), revision) ||
                !RuntimeReleaseArtifact.Equal(freeze.RootElement.GetProperty("chunks_sha256").GetString(), settings.CorpusSha256))
                throw new InvalidOperationException("Corpus does not match released freeze.");
            var corpus = GroundingArtifact.ReadVerified(settings.CorpusPath, settings.CorpusSha256);
            MealRecommendationEvidence[] evidence;
            var question = string.Join(' ', request.Conditions.Concat(request.Nutrients).Concat(request.Ingredients)
                .Append(request.DietaryPattern).Append(request.NutritionGoal));
            if (strategy == "keyword")
            {
                var config = bindings.GetProperty("config");
                if (!RuntimeReleaseArtifact.Equal(RuntimeReleaseArtifact.ContentHash(config), bindings.GetProperty("config_sha256").GetString()))
                    throw new InvalidOperationException("Released config integrity mismatch.");
                var minimum = config.GetProperty("keyword_minimum_score").GetDouble();
                evidence = new KeywordMealKnowledgeIndex(corpus).Search(question, settings.TopK, minimum,
                    freeze.RootElement.GetProperty("source_revision_id").GetString(), editionGuard: true, ct: ct);
            }
            else
            {
                var graphBytes = GroundingArtifact.ReadVerified(settings.ReviewedGraphPath, settings.ReviewedGraphSha256);
                using var graph = JsonDocument.Parse(graphBytes);
                RuntimeReleaseArtifact.Verify(graph.RootElement, "reviewed_retrieval_graph");
                if (ReleaseReviewPolicy.Read(graph.RootElement) != reviewPolicy)
                    throw new InvalidOperationException("Graph review policy differs from release.");
                if (!RuntimeReleaseArtifact.Equal(graph.RootElement.GetProperty("content_sha256").GetString(), bindings.GetProperty("graph_sha256").GetString()) ||
                    !RuntimeReleaseArtifact.Equal(graph.RootElement.GetProperty("corpus_freeze_sha256").GetString(), revision))
                    throw new InvalidOperationException("Graph release binding mismatch.");
                evidence = GraphMealKnowledgeIndex.Load(graphBytes, corpus, "reviewed_retrieval_graph").Retrieve(request, settings.TopK, ct).Evidence;
            }
            // graphRole=retrieval only when the validated release selected graph; otherwise the reviewed
            // graph may only explain citations through a pinned index, else graphRole=none.
            var graphRole = strategy == "graph" ? "retrieval" : "none";
            var explanation = MealGraphExplanationIndex.TryLoad(settings, reviewPolicy, revision);
            if (explanation is not null)
            {
                evidence = MealGraphExplanationIndex.Attach(evidence, explanation);
                if (graphRole == "none") graphRole = "explanation";
            }
            return Task.FromResult(new MealKnowledgeResult(true, revision, strategy, evidence,
                KeywordMealKnowledgeIndex.Tokens(question).Length == 0 ? ["grounding_query_empty"] :
                evidence.Length == 0 ? ["grounding_insufficient_evidence"] : [],
                reviewPolicy == ReleaseReviewPolicy.Reference ? "reference" : "released", reviewPolicy,
                root.GetProperty("intended_use").GetString()) { GraphRole = graphRole });
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or
            InvalidOperationException or KeyNotFoundException or FormatException or ArgumentException or OverflowException)
        {
            return Task.FromResult(MealKnowledgeResult.Unavailable("grounding_release_invalid"));
        }
    }

    private static void ValidateAuthorization(JsonElement root, string manifestHash, string strategy, string environment, string reviewPolicy)
    {
        RuntimeReleaseArtifact.Verify(root, "runtime-integration-authorization");
        if (ReleaseReviewPolicy.Read(root) != reviewPolicy ||
            (reviewPolicy == ReleaseReviewPolicy.Reference && root.GetProperty("role").GetString() != "data_steward"))
            throw new InvalidOperationException("Runtime authorization review policy is invalid.");
        var timestamp = root.GetProperty("timestamp").GetString();
        if (environment is not ("Staging" or "Production") || root.GetProperty("environment").GetString() != environment ||
            !RuntimeReleaseArtifact.Equal(root.GetProperty("manifest_sha256").GetString(), manifestHash) ||
            root.GetProperty("selected_strategy").GetString() != strategy ||
            root.GetProperty("role").GetString() is not ("data_steward" or "dietitian" or "physician") ||
            string.IsNullOrWhiteSpace(root.GetProperty("reviewer_id").GetString()) ||
            string.IsNullOrWhiteSpace(root.GetProperty("comment").GetString()) ||
            timestamp is null || !(timestamp.EndsWith('Z') || timestamp.EndsWith("+00:00", StringComparison.Ordinal)) ||
            !DateTimeOffset.TryParse(timestamp, CultureInfo.InvariantCulture, DateTimeStyles.None, out var signedAt) || signedAt.Offset != TimeSpan.Zero)
            throw new InvalidOperationException("Runtime authorization is invalid.");
    }
}
