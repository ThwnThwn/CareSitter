using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class ReleasedGraphMealKnowledgeRetrieverTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "caresitter-grounding-" + Guid.NewGuid().ToString("N"));

    [Fact]
    public async Task Authorized_reviewed_graph_returns_cited_reachable_chunk()
    {
        var directory = Path.Combine(AppContext.BaseDirectory, "Fixtures", "ReleasedRetrieval");
        string FilePath(string name) => Path.Combine(directory, name);
        var settings = new MealGroundingOptions
        {
            Enabled = true, Mode = MealGroundingOptions.ReleasedGraphMode,
            ManifestPath = FilePath("manifest-graph.json"), ManifestSha256 = Hash(FilePath("manifest-graph.json")),
            RuntimeAuthorizationPath = FilePath("authorization-graph.json"), RuntimeAuthorizationSha256 = Hash(FilePath("authorization-graph.json")),
            CorpusFreezePath = FilePath("freeze.json"), CorpusFreezeSha256 = Hash(FilePath("freeze.json")),
            ReviewedGraphPath = FilePath("graph.json"), ReviewedGraphSha256 = Hash(FilePath("graph.json")),
            CorpusPath = FilePath("corpus.jsonl"), CorpusSha256 = Hash(FilePath("corpus.jsonl"))
        };
        var retriever = new ReleasedGraphMealKnowledgeRetriever(Options.Create(settings),
            new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Staging" });
        var result = await retriever.RetrieveAsync(new(["robot"], [], [], "", ""), CancellationToken.None);
        Assert.True(result.Available);
        Assert.Equal("released", result.ReleaseStatus);
        Assert.NotEmpty(result.Evidence);
    }

    [Fact]
    public async Task No_go_manifest_never_exposes_candidate_evidence()
    {
        Directory.CreateDirectory(_directory);
        var corpus = Write("corpus.jsonl", """
            {"chunk_id":"chunk-1","headings":["Tăng huyết áp"],"index_eligible":true,"pdf_page":35,"printed_page":"34","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:35","text":"Hạn chế natri."}
            """ + Environment.NewLine);
        var graph = Write("graph.json", """
            {"mode":"reviewed_retrieval_graph","nodes":[{"id":"topic-1","label":"tăng huyết áp","type":"topic"},{"id":"chunk-1","label":"chunk-1","type":"chunk","chunk_id":"chunk-1"}],"edges":[{"from":"topic-1","to":"chunk-1"}]}
            """);
        var manifest = Write("manifest.json", """
            {"release_ready":false,"runtime_integration_authorized":false,"decision":"no_go",
             "selected_strategy":null,"gate_failures":["review.pending"],
             "bindings":{"corpus_freeze_sha256":"freeze-v1","graph_sha256":null}}
            """);
        var retriever = new ReleasedGraphMealKnowledgeRetriever(Options.Create(OptionsFor(manifest, graph, corpus)), new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Staging" });

        var result = await retriever.RetrieveAsync(new MealKnowledgeRequest(
            ["Tăng huyết áp"], [], [], "regular", "maintain"), CancellationToken.None);

        Assert.False(result.Available);
        Assert.Empty(result.Evidence);
        Assert.Equal(["grounding_release_invalid"], result.Warnings);
    }

    [Fact]
    public void Enabled_options_require_absolute_paths_hashes_and_bounded_top_k()
    {
        var validator = new MealGroundingOptionsValidator();
        var result = validator.Validate(null, new MealGroundingOptions
        {
            Enabled = true, ManifestPath = "relative.json", ManifestSha256 = "bad", TopK = 11
        });

        Assert.True(result.Failed);
    }

    private MealGroundingOptions OptionsFor(string manifest, string graph, string corpus) => new()
    {
        Enabled = true,
        ManifestPath = manifest,
        ManifestSha256 = Hash(manifest),
        ReviewedGraphPath = graph,
        ReviewedGraphSha256 = Hash(graph),
        CorpusPath = corpus,
        CorpusSha256 = Hash(corpus),
        TopK = 5
    };

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
}
