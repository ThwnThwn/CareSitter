using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class OwnerAuthorizedCorpusMealKnowledgeRetrieverTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(),
        "caresitter-demo-grounding-" + Guid.NewGuid().ToString("N"));

    [Fact]
    public async Task Development_owner_authorized_demo_returns_corpus_evidence()
    {
        Directory.CreateDirectory(_directory);
        var corpus = Write("corpus.jsonl", """
            {"chunk_id":"chunk-1","source_id":"book-dinh-duong-lam-sang-2019","headings":["Tăng huyết áp","Chế độ ăn"],"index_eligible":true,"pdf_page":35,"printed_page":"34","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:35","text":"Hạn chế natri trong chế độ ăn cho người tăng huyết áp."}
            """ + Environment.NewLine);
        var authorization = Authorization(corpus, independent: false);
        var retriever = new OwnerAuthorizedCorpusMealKnowledgeRetriever(
            Options.Create(OptionsFor(authorization, corpus)), new TestEnvironment("Development"));

        var result = await retriever.RetrieveAsync(new MealKnowledgeRequest(
            ["Tăng huyết áp"], ["natri"], [], "regular", "maintain"), CancellationToken.None);

        Assert.True(result.Available);
        Assert.Equal(MealGroundingOptions.OwnerAuthorizedCorpusDemoMode, result.Strategy);
        Assert.Single(result.Evidence);
        Assert.Equal("chunk-1", result.Evidence[0].Id);
        Assert.Contains("academic_demo_owner_authorized", result.Warnings);
        Assert.Contains("independent_clinical_review_not_claimed", result.Warnings);
    }

    [Fact]
    public async Task Demo_mode_is_rejected_outside_development()
    {
        Directory.CreateDirectory(_directory);
        var corpus = Write("corpus.jsonl", """
            {"chunk_id":"chunk-1","source_id":"book-dinh-duong-lam-sang-2019","headings":["Tăng huyết áp"],"index_eligible":true,"pdf_page":35,"printed_page":"34","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:35","text":"Hạn chế natri."}
            """ + Environment.NewLine);
        var authorization = Authorization(corpus, independent: false);
        var retriever = new OwnerAuthorizedCorpusMealKnowledgeRetriever(
            Options.Create(OptionsFor(authorization, corpus)), new TestEnvironment("Production"));

        var result = await retriever.RetrieveAsync(new MealKnowledgeRequest(
            ["Tăng huyết áp"], [], [], "regular", "maintain"), CancellationToken.None);

        Assert.False(result.Available);
        Assert.Equal(["grounding_demo_authorization_invalid"], result.Warnings);
    }

    [Fact]
    public async Task Authorization_cannot_claim_independent_clinical_review()
    {
        Directory.CreateDirectory(_directory);
        var corpus = Write("corpus.jsonl", """
            {"chunk_id":"chunk-1","source_id":"book-dinh-duong-lam-sang-2019","headings":["Dinh dưỡng"],"index_eligible":true,"pdf_page":1,"printed_page":"1","review_status":"ready_for_retrieval_eval","source_locator":"pdf-page:1","text":"Nội dung."}
            """ + Environment.NewLine);
        var authorization = Authorization(corpus, independent: true);
        var retriever = new OwnerAuthorizedCorpusMealKnowledgeRetriever(
            Options.Create(OptionsFor(authorization, corpus)), new TestEnvironment("Development"));

        var result = await retriever.RetrieveAsync(new MealKnowledgeRequest(
            ["Dinh dưỡng"], [], [], "regular", "maintain"), CancellationToken.None);

        Assert.False(result.Available);
    }

    [Fact]
    public void Demo_options_require_authorization_and_corpus_hashes()
    {
        var result = new MealGroundingOptionsValidator().Validate(null, new MealGroundingOptions
        {
            Enabled = true,
            Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode,
            CorpusPath = "relative.jsonl",
            CorpusSha256 = "bad",
            DemoAuthorizationPath = "relative.json",
            DemoAuthorizationSha256 = "bad"
        });

        Assert.True(result.Failed);
    }

    private string Authorization(string corpus, bool independent) => Write("authorization.json", $$"""
        {
          "mode":"owner_authorized_academic_demo",
          "authorized_environment":"Development",
          "authorized_use":"academic_demo",
          "owner_accepted":true,
          "reviewer_type":"ai_assisted",
          "accepted_cases":54,
          "total_cases":54,
          "independent_clinical_review":{{independent.ToString().ToLowerInvariant()}},
          "corpus_sha256":"{{Hash(corpus)}}",
          "case_set_sha256":"case-v9"
        }
        """);

    private MealGroundingOptions OptionsFor(string authorization, string corpus) => new()
    {
        Enabled = true,
        Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode,
        DemoAuthorizationPath = authorization,
        DemoAuthorizationSha256 = Hash(authorization),
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

    private sealed class TestEnvironment(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "CareSitter.Nutrition.Tests";
        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
