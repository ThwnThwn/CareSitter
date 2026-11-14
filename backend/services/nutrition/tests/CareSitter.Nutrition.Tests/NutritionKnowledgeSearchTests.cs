using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class NutritionKnowledgeSearchTests
{
    [Theory]
    [InlineData("ăn giảm cân")]
    [InlineData("ăn gì để giảm cân")]
    public async Task Weight_management_short_query_matches_obesity_section_without_extra_inference(string query)
    {
        var path = Path.GetTempFileName();
        const string passage = "Đây là đoạn dữ liệu thử nghiệm về khẩu phần của người béo phì.";
        try
        {
            await File.WriteAllTextAsync(path, Chunk(passage, heading: "1. Béo phì"));
            var bytes = await File.ReadAllBytesAsync(path);
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            { Enabled = true, CorpusPath = path, CorpusSha256 = Convert.ToHexString(SHA256.HashData(bytes)),
                Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode }),
                new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Development" });
            Assert.Equal(passage, Assert.Single(await search.FindAsync(query, default, true)).Excerpt);
        }
        finally { File.Delete(path); }
    }
    [Theory]
    [InlineData("trái cây tốt cho người cao huyết áp")]
    [InlineData("trai cay tot cho nguoi cao huyet ap")]
    [InlineData("người tăng huyết áp nên ăn hoa quả nào?")]
    public async Task Natural_question_matches_synonyms_and_condition_in_section_heading(string query)
    {
        var path = Path.GetTempFileName();
        const string passage = "Đây là đoạn dữ liệu thử nghiệm về hoa quả trong thực đơn.";
        try
        {
            await File.WriteAllTextAsync(path, Chunk(passage, heading: "Dinh dưỡng cho người tăng huyết áp"));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path, Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }), new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Development" });
            var hit = Assert.Single(await search.FindAsync(query, CancellationToken.None, true));
            Assert.Equal(passage, hit.Excerpt);
            Assert.Empty(await search.FindAsync("trái cây cho người tiểu đường", CancellationToken.None, true));
        }
        finally { File.Delete(path); }
    }
    [Theory]
    [InlineData("chat xo co tac dung gi", "Chất xơ giúp duy trì hoạt động tiêu hóa bình thường.")]
    [InlineData("chất xơ", "Chất\nxơ giúp duy trì hoạt động tiêu hóa bình thường.")]
    [InlineData("chất xơ", "Chất xơ giúp duy trì hoạt động tiêu hóa bình thường, " )]
    public async Task Search_matches_natural_questions_and_wrapped_passages(string query, string passage)
    {
        if (passage.EndsWith(", ")) passage += new string('a', 260) + ".";
        var path = Path.GetTempFileName();
        try
        {
            await File.WriteAllTextAsync(path, Chunk(passage));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path, Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }), new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Development" });
            var hit = Assert.Single(await search.FindAsync(query, CancellationToken.None, localDemo: true));
            Assert.Equal(passage.Replace('\n', ' '), hit.Excerpt);
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public async Task Demo_fuses_graph_ranking_instead_of_replacing_it_with_keyword_search()
    {
        var path = Path.GetTempFileName();
        try
        {
            await File.WriteAllTextAsync(path, string.Join('\n',
                Chunk("Chất xơ có trong khẩu phần thử nghiệm.", "chunk-1", "Thực phẩm"),
                Chunk("Chất xơ có trong khẩu phần thử nghiệm.", "chunk-2", "Chất xơ")));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path, TopK = 1, Mode = MealGroundingOptions.OwnerAuthorizedGraphDemoMode,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }), new Microsoft.Extensions.Hosting.Internal.HostingEnvironment { EnvironmentName = "Development" });
            Assert.Equal("chunk-1", Assert.Single(await search.FindAsync("chất xơ", CancellationToken.None, true)).ChunkId);
        }
        finally { File.Delete(path); }
    }

    [Theory]
    [InlineData("dứa có tác dụng gì", "Dừa có trong khẩu phần thử nghiệm.")]
    [InlineData("trái thơm tốt cho gì", "Dưa có trong khẩu phần thử nghiệm.")]
    [InlineData("dừa có lợi ích gì", "Dứa có trong khẩu phần thử nghiệm.")]
    public async Task Accent_folding_does_not_confuse_distinct_fruits(string query, string passage)
    {
        var path = Path.GetTempFileName();
        try
        {
            await File.WriteAllTextAsync(path, Chunk(passage));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }));
            Assert.Empty(await search.FindAsync(query, CancellationToken.None));
        }
        finally { File.Delete(path); }
    }
    [Fact]
    public async Task Search_returns_released_metadata_without_book_text()
    {
        var path = Path.GetTempFileName();
        try
        {
            File.WriteAllText(path, Chunk(), new UTF8Encoding(false));
            var digest = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path, CorpusSha256 = digest
            }));
            var hit = Assert.Single(await search.FindAsync("chất xơ", CancellationToken.None));
            Assert.Equal("chunk-1", hit.ChunkId);
            Assert.Equal(42, hit.PdfPage);
            Assert.Equal("41", hit.PrintedPage);
            var wire = JsonSerializer.Serialize(hit);
            Assert.DoesNotContain("SECRET_BOOK_TEXT", wire);
            Assert.DoesNotContain("Excerpt", wire);
        }
        finally { File.Delete(path); }
    }

    [Theory]
    [InlineData("trái thơm tốt cho gì")]
    [InlineData("khóm có lợi ích gì?")]
    public async Task Search_does_not_show_unrelated_results_for_pineapple(string query)
    {
        var path = Path.GetTempFileName();
        try
        {
            await File.WriteAllTextAsync(path, Chunk(), new UTF8Encoding(false));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }));
            Assert.Empty(await search.FindAsync(query, CancellationToken.None));
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public async Task Search_rejects_changed_corpus()
    {
        var path = Path.GetTempFileName();
        try
        {
            File.WriteAllText(path, Chunk(), new UTF8Encoding(false));
            var search = new NutritionKnowledgeSearch(new ReleasedRetriever(), Options.Create(new MealGroundingOptions
            {
                Enabled = true, CorpusPath = path, CorpusSha256 = new string('0', 64)
            }));
            await Assert.ThrowsAsync<InvalidOperationException>(() => search.FindAsync("chất xơ", CancellationToken.None));
        }
        finally { File.Delete(path); }
    }

    private static string Chunk(string text = "SECRET_BOOK_TEXT", string id = "chunk-1", string heading = "Chất xơ") => JsonSerializer.Serialize(new
    {
        chunk_id = id, source_revision_id = "fixture-r1", index_eligible = true, source_locator = "PDF trang 42",
        review_status = "ready_for_retrieval_eval", text, pdf_page = 42,
        printed_page = "41", headings = new[] { heading }
    });

    private sealed class ReleasedRetriever : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(new MealKnowledgeResult(true, "fixture-r1", "keyword",
                [new MealRecommendationEvidence("chunk-1", "Chất xơ", "Chương", "41", "PDF trang 42",
                    "Nguồn", "SECRET_BOOK_TEXT") { SourceTitle = "Tài liệu thử" }], [], "reference"));
    }
}
