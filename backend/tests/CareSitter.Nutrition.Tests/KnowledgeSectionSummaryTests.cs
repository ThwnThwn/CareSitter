using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Hosting.Internal;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class KnowledgeSectionSummaryTests
{
    private const string Target = "2. Nguyên tắc chế độ dinh dưỡng";
    private const string Overview = "Chế độ dinh dưỡng cho tăng huyết áp được mô tả trong mục này bằng dữ liệu thử nghiệm.";
    private const string Detail = "Thông tin khẩu phần cần được đối chiếu với hướng dẫn của người phụ trách chuyên môn.";
    private const string Text = "Nội dung nối từ trang trước về nguyên nhân tăng huyết áp.\n\n" +
        "2.1. Tăng huyết áp thứ phát\n\nTùy vào nguyên nhân gây bệnh.\n\n" + Target + "\n\n" + Overview + "\n\n" + Detail +
        "\n\n3. Tài liệu tham khảo\n\nTăng huyết áp trong tài liệu khác không thuộc mục đang xem.";

    [Fact]
    public async Task Summary_and_excerpt_stay_in_the_named_section_not_the_page_prefix()
    {
        var hit = Assert.Single(await FindAsync(true, "Development"));
        Assert.Equal(Target, hit.Heading);
        Assert.Equal(Overview, hit.Excerpt);
        Assert.Equal(Overview + " " + Detail, hit.Summary);
        Assert.DoesNotContain("Tùy vào", hit.Summary);
        Assert.DoesNotContain("Nội dung nối", hit.Summary);
        Assert.DoesNotContain("tài liệu khác", hit.Summary);
    }

    [Theory]
    [InlineData(false, "Development")]
    [InlineData(true, "Production")]
    public async Task Summary_and_excerpt_do_not_leave_the_local_authorized_flow(bool localDemo, string environment)
    {
        var hit = Assert.Single(await FindAsync(localDemo, environment));
        Assert.Null(hit.Summary);
        Assert.Null(hit.Excerpt);
        var wire = JsonSerializer.Serialize(hit);
        Assert.DoesNotContain(Overview, wire);
        Assert.DoesNotContain("Summary", wire);
    }

    [Fact]
    public async Task Heading_only_match_does_not_invent_a_summary()
    {
        var hits = await FindAsync(true, "Development", body: "Tăng huyết áp\n\nDòng ngắn.", headings: ["Tăng huyết áp"]);
        Assert.Null(Assert.Single(hits).Summary);
    }

    [Fact]
    public async Task Child_sections_keep_the_parent_topic_without_borrowing_a_sibling_disease()
    {
        const string section = "DINH DƯỠNG CHO NGƯỜI TĂNG HUYẾT ÁP";
        var hit = Assert.Single(await FindAsync(true, "Development", title: "1. Trái cây",
            body: section + "\n\n1. Trái cây\n\nHoa quả được mô tả trong khẩu phần của dữ liệu thử nghiệm.",
            headings: [section, "1. Trái cây"], query: "trái cây cho người tăng huyết áp"));
        Assert.Equal("1. Trái cây", hit.Heading);
        Assert.Contains("Hoa quả", hit.Summary);

        Assert.Empty(await FindAsync(true, "Development", title: "2. Đái tháo đường",
            body: "1. Tăng huyết áp\n\nNội dung thử nghiệm về hoạt động hằng ngày.\n\n" +
                "2. Đái tháo đường\n\nHoa quả được mô tả trong khẩu phần của dữ liệu thử nghiệm.",
            headings: ["1. Tăng huyết áp", "2. Đái tháo đường"], query: "trái cây cho người tăng huyết áp"));
    }

    [Fact]
    public async Task Diagram_ocr_is_not_reused_as_a_prose_summary()
    {
        var hit = Assert.Single(await FindAsync(true, "Development", title: "Tăng huyết áp",
            body: "Tăng huyết áp\n\nTăng huyết áp động \ue069 Blood pressure Stimuli trong hình minh họa được trộn với văn bản.",
            headings: ["Tăng huyết áp"]));
        Assert.Null(hit.Summary);
        Assert.Null(hit.Excerpt);
    }

    [Fact]
    public async Task Search_updates_a_page_title_to_the_section_actually_matching_the_question()
    {
        var hit = Assert.Single(await FindAsync(true, "Development", title: "3. Tài liệu tham khảo",
            body: "1. Chất xơ\n\nChất xơ có trong khẩu phần được ghi nhận trong dữ liệu thử nghiệm.\n\n" +
                "3. Tài liệu tham khảo\n\nDanh mục các tài liệu tham khảo được trình bày riêng tại đây.",
            headings: ["1. Chất xơ", "3. Tài liệu tham khảo"], query: "chất xơ"));
        Assert.Equal("1. Chất xơ", hit.Heading);
        Assert.Contains("Chất xơ", hit.Summary);
        Assert.DoesNotContain("Danh mục", hit.Summary);
    }

    private static async Task<IReadOnlyList<KnowledgeSearchHit>> FindAsync(bool localDemo, string environment,
        string body = Text, string title = Target, string[]? headings = null, string query = "tăng huyết áp")
    {
        var path = Path.GetTempFileName();
        try
        {
            await File.WriteAllTextAsync(path, JsonSerializer.Serialize(new
            {
                chunk_id = "fixture", source_revision_id = "fixture-r1", index_eligible = true,
                review_status = "ready_for_retrieval_eval", text = body, source_locator = "PDF trang 136",
                pdf_page = 136, printed_page = "135", headings = headings ?? ["2.1. Tăng huyết áp thứ phát", Target, "3. Tài liệu tham khảo"]
            }));
            var search = new NutritionKnowledgeSearch(new Retriever(title), Options.Create(new MealGroundingOptions
            {
                Enabled = true, Mode = MealGroundingOptions.OwnerAuthorizedCorpusDemoMode, CorpusPath = path,
                CorpusSha256 = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(path)))
            }), new HostingEnvironment { EnvironmentName = environment });
            return await search.FindAsync(query, CancellationToken.None, localDemo);
        }
        finally { File.Delete(path); }
    }

    private sealed class Retriever(string title) : IMealKnowledgeRetriever
    {
        public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
            Task.FromResult(new MealKnowledgeResult(true, "fixture-r1", "keyword",
                [new MealRecommendationEvidence("fixture", title, "Chương", "135", "PDF trang 136", "Tài liệu thử", "fixture")], [], "reference"));
    }
}
