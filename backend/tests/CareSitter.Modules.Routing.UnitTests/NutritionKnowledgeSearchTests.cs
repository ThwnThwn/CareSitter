using System.Security.Cryptography;
using System.Text;
using CareSitter.ApiHost.Nutrition;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Routing.UnitTests;

public sealed class NutritionKnowledgeSearchTests
{
    [Fact]
    public void Search_returns_matching_excerpt_and_pdf_citation_only_from_eligible_source()
    {
        var path = Path.GetTempFileName();
        try
        {
            var lines = new[]
            {
                Chunk("eligible", "Chất xơ", "Chất xơ có trong rau và quả.", true, 42),
                Chunk("excluded", "Chất xơ", "Thông tin chưa được kiểm tra.", false, 43),
                Chunk("other", "Chất xơ", "Thông tin nguồn khác.", true, 44,
                    "unrelated-source")
            };
            File.WriteAllLines(path, lines, Encoding.UTF8);
            var digest = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
            var search = new NutritionKnowledgeSearch(Options.Create(new NutritionKnowledgeOptions
            {
                Enabled = true, CorpusPath = path, CorpusSha256 = digest
            }));

            var hit = Assert.Single(search.Find("chất xơ"));
            Assert.Equal("eligible", hit.ChunkId);
            Assert.Equal(42, hit.PdfPage);
            Assert.Equal("41", hit.PrintedPage);
            Assert.Contains("rau và quả", hit.Excerpt);
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public void Search_rejects_changed_corpus()
    {
        var path = Path.GetTempFileName();
        try
        {
            File.WriteAllText(path, Chunk("eligible", "Chất xơ", "Rau chứa chất xơ.", true, 42));
            var search = new NutritionKnowledgeSearch(Options.Create(new NutritionKnowledgeOptions
            {
                Enabled = true, CorpusPath = path, CorpusSha256 = new string('0', 64)
            }));
            Assert.Throws<InvalidOperationException>(() => search.Find("chất xơ"));
        }
        finally { File.Delete(path); }
    }

    [Fact]
    public void Search_centers_excerpt_on_vietnamese_match()
    {
        var path = Path.GetTempFileName();
        try
        {
            File.WriteAllText(path, Chunk("eligible", "Khẩu phần",
                new string('a', 480) + " Chất xơ có trong rau.", true, 42));
            var digest = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path)));
            var search = new NutritionKnowledgeSearch(Options.Create(new NutritionKnowledgeOptions
            {
                Enabled = true, CorpusPath = path, CorpusSha256 = digest
            }));
            Assert.Contains("Chất xơ", Assert.Single(search.Find("chất xơ")).Excerpt);
        }
        finally { File.Delete(path); }
    }

    private static string Chunk(string id, string heading, string text, bool eligible, int page,
        string sourceId = "book-dinh-duong-lam-sang-2019") =>
        System.Text.Json.JsonSerializer.Serialize(new
        {
            chunk_id = id, source_revision_id = "book@fixture", source_id = sourceId,
            index_eligible = eligible, headings = new[] { heading }, text,
            pdf_page = page, printed_page = "41"
        });
}
