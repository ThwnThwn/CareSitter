using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Nodes;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class OwnerAuthorizedGraphMealKnowledgeRetrieverTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "caresitter-graph-demo-" + Guid.NewGuid().ToString("N"));
    private readonly MealKnowledgeRequest _query = new(["đậu phụ"], [], [], "", "");

    [Fact]
    public async Task Demo_traverses_two_hops_and_cites_only_reachable_eligible_chunks()
    {
        var options = Fixture();
        var result = await Retriever(options).RetrieveAsync(_query, CancellationToken.None);

        Assert.True(result.Available);
        Assert.Equal(MealGroundingOptions.OwnerAuthorizedGraphDemoMode, result.Strategy);
        Assert.Equal("freeze-v1", result.Revision);
        var evidence = Assert.Single(result.Evidence);
        Assert.Equal("chunk-1", evidence.Id);
        Assert.Equal("34", evidence.PrintedPages);
        Assert.Contains("trang 34", evidence.Reference);
        Assert.Contains("graph_candidate_not_independently_reviewed", result.Warnings);
        Assert.Contains("independent_clinical_review_not_claimed", result.Warnings);
    }

    [Theory]
    [InlineData("Production", true)]
    [InlineData("Staging", true)]
    [InlineData("Development", false)]
    public async Task Demo_cannot_run_outside_development_local_demo_catalog(string environment, bool catalogEnabled)
    {
        var result = await Retriever(Fixture(), environment, catalogEnabled).RetrieveAsync(_query, CancellationToken.None);

        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Contains("grounding_graph_demo_authorization_invalid", result.Warnings);
    }

    [Theory]
    [InlineData("graph_binding")]
    [InlineData("corpus_binding")]
    [InlineData("freeze_binding")]
    [InlineData("clinical_claim")]
    [InlineData("production_claim")]
    [InlineData("missing_owner_acceptance")]
    [InlineData("tampered_graph")]
    [InlineData("dangling_edge")]
    [InlineData("ineligible_chunk")]
    [InlineData("reviewed_mode")]
    public async Task Invalid_authorization_or_graph_falls_back_without_exposing_evidence(string failure)
    {
        var result = await Retriever(Fixture(failure)).RetrieveAsync(_query, CancellationToken.None);

        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Equal(MealGroundingOptions.OwnerAuthorizedGraphDemoMode, result.Strategy);
        Assert.Contains("grounding_graph_demo_authorization_invalid", result.Warnings);
    }

    [Fact]
    public async Task Missing_topic_returns_no_evidence_with_demo_disclosure()
    {
        var result = await Retriever(Fixture()).RetrieveAsync(
            new(["unmatchedword"], [], [], "", ""), CancellationToken.None);

        Assert.True(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Contains("grounding_insufficient_evidence", result.Warnings);
        Assert.Contains("independent_clinical_review_not_claimed", result.Warnings);
    }

    [Fact]
    public void Enabled_graph_demo_requires_a_graph_path_and_digest()
    {
        var result = new MealGroundingOptionsValidator().Validate(null, Fixture(omitGraphBinding: true));
        Assert.True(result.Failed);
    }

    private OwnerAuthorizedGraphMealKnowledgeRetriever Retriever(MealGroundingOptions options,
        string environment = "Development", bool catalogEnabled = true) => new(Options.Create(options),
        new TestEnvironment(environment), new(catalogEnabled, LocalDemoCatalogOptions.DefaultPackageKey));

    private MealGroundingOptions Fixture(string? failure = null, bool omitGraphBinding = false)
    {
        Directory.CreateDirectory(_directory);
        var corpus = Write("corpus.jsonl", """
            {"chunk_id":"chunk-1","headings":["Chương 1","Thực phẩm"],"index_eligible":true,"pdf_page":35,"printed_page":"34","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:35","text":"Nội dung tham khảo thứ nhất."}
            {"chunk_id":"chunk-2","headings":["Chương 2"],"index_eligible":true,"pdf_page":36,"printed_page":"35","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:36","text":"Nội dung ngoài giới hạn hai bước."}
            {"chunk_id":"chunk-3","headings":["Chương 3"],"index_eligible":true,"pdf_page":37,"printed_page":"36","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:37","text":"Đoạn không có liên kết."}
            """.Replace("\"index_eligible\":true", failure == "ineligible_chunk" ? "\"index_eligible\":false" : "\"index_eligible\":true", StringComparison.Ordinal));
        var graphJson = JsonNode.Parse("""
            {"mode":"retrieval_graph_candidate","corpus_freeze_sha256":"freeze-v1","nodes":[
              {"id":"topic-1","label":"đậu phụ","type":"topic"},
              {"id":"topic-2","label":"bridge","type":"topic"},
              {"id":"chunk-1","label":"chunk-1","type":"chunk","chunk_id":"chunk-1"},
              {"id":"chunk-2","label":"chunk-2","type":"chunk","chunk_id":"chunk-2"},
              {"id":"chunk-3","label":"chunk-3","type":"chunk","chunk_id":"chunk-3"}
            ],"edges":[{"from":"topic-1","to":"topic-2"},{"from":"topic-2","to":"chunk-1"},
              {"from":"chunk-1","to":"chunk-2"},{"from":"topic-2","to":"topic-1"}]}
            """)!;
        if (failure == "dangling_edge") graphJson["edges"]![0]!["to"] = "missing-node";
        if (failure == "reviewed_mode") graphJson["mode"] = "reviewed_retrieval_graph";
        var graph = Write("graph.json", graphJson.ToJsonString());
        var graphHash = Hash(graph);
        var authorizationJson = JsonNode.Parse($$"""
            {"schema_version":1,"authorization_id":"fixture-owner-request","mode":"owner_authorized_graph_demo",
             "authorized_environment":"Development","authorized_use":"academic_demo","owner_accepted":true,
             "graph_review_status":"candidate_not_independently_reviewed","independent_clinical_review":false,
             "production_release_authorized":false,"graph_sha256":"{{graphHash}}",
             "corpus_sha256":"{{Hash(corpus)}}","corpus_freeze_sha256":"freeze-v1"}
            """)!;
        switch (failure)
        {
            case "graph_binding": authorizationJson["graph_sha256"] = new string('a', 64); break;
            case "corpus_binding": authorizationJson["corpus_sha256"] = new string('b', 64); break;
            case "freeze_binding": authorizationJson["corpus_freeze_sha256"] = "another-freeze"; break;
            case "clinical_claim": authorizationJson["independent_clinical_review"] = true; break;
            case "production_claim": authorizationJson["production_release_authorized"] = true; break;
            case "missing_owner_acceptance": authorizationJson.AsObject().Remove("owner_accepted"); break;
            case "tampered_graph": Write("graph.json", "{}"); break;
        }
        var authorization = Write("authorization.json", authorizationJson.ToJsonString());
        return new MealGroundingOptions
        {
            Enabled = true, Mode = MealGroundingOptions.OwnerAuthorizedGraphDemoMode,
            DemoAuthorizationPath = authorization, DemoAuthorizationSha256 = Hash(authorization),
            DemoGraphPath = omitGraphBinding ? "" : graph, DemoGraphSha256 = omitGraphBinding ? "" : graphHash,
            CorpusPath = corpus, CorpusSha256 = Hash(corpus), TopK = 5
        };
    }

    private string Write(string name, string content)
    {
        var path = Path.Combine(_directory, name);
        File.WriteAllText(path, content, new UTF8Encoding(false));
        return path;
    }

    private static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));

    public void Dispose()
    {
        if (Directory.Exists(_directory)) Directory.Delete(_directory, true);
    }

    private sealed class TestEnvironment(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "CareSitter.Nutrition.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
