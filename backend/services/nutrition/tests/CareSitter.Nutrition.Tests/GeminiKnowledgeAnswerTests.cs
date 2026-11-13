using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Tests;

public sealed class GeminiKnowledgeAnswerTests
{
    private const string Passage = "Đây là nội dung dữ liệu thử nghiệm về thực phẩm.";

    [Theory]
    [InlineData(true, "answered")]
    [InlineData(false, "invalid_output")]
    public async Task Invalid_output_gets_one_bounded_repair_with_source_checks_preserved(bool repairSucceeds, string expected)
    {
        var invalid = JsonSerializer.Serialize(new { status = "answered", blocks = new[] { new
        { text = "Câu trả lời thử nghiệm.", evidence = new[] { new { index = 1, quote = "Đoạn bịa không tồn tại ở nguồn" } } } } });
        var valid = JsonSerializer.Serialize(new { status = "answered", blocks = new[] { new
        { text = "Câu trả lời thử nghiệm.", evidence = new[] { new { index = 1, quote = Passage } } } } });
        using var handler = new Handler(invalid, repairSucceeds ? valid : null);
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var result = await Create(client, true).AnswerAsync("Câu hỏi", [Hit()], CancellationToken.None);
        Assert.Equal(expected, result.Status);
        Assert.Equal(2, handler.Calls);
        using var body = JsonDocument.Parse(handler.Body!);
        using var prompt = JsonDocument.Parse(body.RootElement.GetProperty("contents")[0].GetProperty("parts")[0].GetProperty("text").GetString()!);
        Assert.Contains("invalid_support_quote", prompt.RootElement.GetProperty("validationFeedback").GetString());
        Assert.DoesNotContain("Đoạn bịa", prompt.RootElement.GetRawText());
    }

    [Theory]
    [InlineData(4, 80)]
    [InlineData(5, 80)]
    [InlineData(1, 1100)]
    public async Task Supported_paragraph_is_not_rejected_by_inconsistent_shape_limits(int sourceCount, int textLength)
    {
        using var handler = new Handler(JsonSerializer.Serialize(new
        {
            status = "answered", blocks = new[] { new { text = new string('a', textLength),
                evidence = Enumerable.Range(1, sourceCount).Select(index => new { index, quote = Passage }).ToArray() } }
        }));
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var hits = Enumerable.Range(1, sourceCount).Select(index => new KnowledgeSearchHit($"source-{index}", "Mục thử", index, null, "Nguồn thử", "r1", Passage)).ToArray();
        var result = await Create(client, true).AnswerAsync("Câu hỏi thử nghiệm", hits, CancellationToken.None);
        Assert.Equal("answered", result.Status);
        Assert.Equal(sourceCount, result.ChunkIds.Count);
    }

    [Fact]
    public async Task Answer_may_cite_all_five_supplied_sources_instead_of_being_reported_as_offline()
    {
        using var handler = new Handler(JsonSerializer.Serialize(new
        {
            status = "answered", blocks = new[]
            {
                new { text = "Đoạn giải thích thứ nhất từ nguồn thử nghiệm.", evidence = new[] { new { index = 1, quote = Passage }, new { index = 2, quote = Passage } } },
                new { text = "Đoạn giải thích thứ hai từ nguồn thử nghiệm.", evidence = new[] { new { index = 3, quote = Passage }, new { index = 4, quote = Passage } } },
                new { text = "Đoạn giải thích thứ ba từ nguồn thử nghiệm.", evidence = new[] { new { index = 5, quote = Passage } } }
            }
        }));
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var hits = Enumerable.Range(1, 5).Select(index => new KnowledgeSearchHit($"source-{index}", "Mục thử", index, null, "Nguồn thử", "r1", Passage)).ToArray();
        var result = await Create(client, true).AnswerAsync("Câu hỏi thử nghiệm", hits, CancellationToken.None);
        Assert.Equal("answered", result.Status);
        Assert.Equal(5, result.ChunkIds.Count);
    }

    [Theory]
    [InlineData(1, "Đây là nội dung dữ liệu thử nghiệm", "answered")]
    [InlineData(99, "Đây là nội dung dữ liệu thử nghiệm", "invalid_output")]
    [InlineData(1, "Nội dung bịa ra không có trong tài liệu", "invalid_output")]
    public async Task Generated_paragraph_requires_a_valid_source_and_exact_support_quote(int index, string quote, string status)
    {
        using var handler = new Handler(JsonSerializer.Serialize(new
        {
            status = "answered", blocks = new[] { new { text = "Câu trả lời được diễn giải từ nguồn thử nghiệm.",
                evidence = new[] { new { index, quote } } } }
        }));
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var service = Create(client, true);
        var result = await service.AnswerAsync("Câu hỏi thử nghiệm", [Hit()], CancellationToken.None);
        Assert.Equal(status, result.Status);
        Assert.Equal(status == "answered" ? new[] { "source-1" } : [], result.ChunkIds);
        Assert.DoesNotContain("fixture-key", handler.Body);
        using var body = JsonDocument.Parse(handler.Body!);
        using var prompt = JsonDocument.Parse(body.RootElement.GetProperty("contents")[0]
            .GetProperty("parts")[0].GetProperty("text").GetString()!);
        Assert.Equal(Passage, prompt.RootElement.GetProperty("sources")[0].GetProperty("text").GetString());
    }

    [Fact]
    public async Task Disabled_or_unapproved_processing_never_calls_provider()
    {
        using var handler = new Handler("{}");
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        Assert.Equal("not_configured", (await Create(client, false).AnswerAsync("Câu hỏi", [Hit()], CancellationToken.None)).Status);
        Assert.Equal(0, handler.Calls);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Missing_evidence_returns_explicit_uncited_suggestion(bool hasRelatedSource)
    {
        var suggestion = JsonSerializer.Serialize(new { status = "ai_suggestion", blocks = new[] {
            new { text = "Gợi ý kiến thức chung, chưa đối chiếu tài liệu.", evidence = Array.Empty<object>() } } });
        using var handler = new Handler(hasRelatedSource ? "{\"status\":\"insufficient_evidence\",\"blocks\":[]}" : suggestion, suggestion);
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var result = await Create(client, true).AnswerAsync("Câu hỏi", hasRelatedSource ? [Hit()] : [], CancellationToken.None);
        Assert.Equal("ai_suggestion", result.Status);
        Assert.Empty(result.ChunkIds);
        Assert.Single(result.Blocks);
        Assert.Equal(hasRelatedSource ? 2 : 1, handler.Calls);
        using var body = JsonDocument.Parse(handler.Body!);
        using var prompt = JsonDocument.Parse(body.RootElement.GetProperty("contents")[0].GetProperty("parts")[0].GetProperty("text").GetString()!);
        Assert.Empty(prompt.RootElement.GetProperty("sources").EnumerateArray());
    }

    [Fact]
    public async Task Suggestion_must_not_claim_source_evidence()
    {
        using var handler = new Handler(JsonSerializer.Serialize(new { status = "ai_suggestion", blocks = new[] {
            new { text = "Gợi ý kiến thức chung có nguồn bịa.", evidence = new[] { new { index = 1, quote = Passage } } } } }));
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var result = await Create(client, true).AnswerAsync("Câu hỏi", [], CancellationToken.None);
        Assert.Equal("invalid_output", result.Status);
        Assert.Empty(result.Blocks);
    }

    [Theory]
    [InlineData(HttpStatusCode.TooManyRequests, "rate_limited")]
    [InlineData(HttpStatusCode.ServiceUnavailable, "unavailable")]
    public async Task Provider_errors_do_not_start_a_suggestion_request(HttpStatusCode status, string expected)
    {
        using var handler = new Handler("{}") { Status = status };
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        var result = await Create(client, true).AnswerAsync("Câu hỏi", [Hit()], CancellationToken.None);
        Assert.Equal(expected, result.Status);
        Assert.Empty(result.Blocks);
        Assert.Equal(1, handler.Calls);
    }

    [Fact]
    public async Task Cancelled_request_never_starts_a_provider_request()
    {
        using var handler = new Handler("{}");
        using var client = new HttpClient(handler) { BaseAddress = new Uri("https://generativelanguage.googleapis.com/v1beta/") };
        using var cancelled = new CancellationTokenSource();
        cancelled.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Create(client, true).AnswerAsync("Câu hỏi", [], cancelled.Token));
        Assert.Equal(0, handler.Calls);
    }

    private static GeminiKnowledgeAnswer Create(HttpClient client, bool approved) => new(client,
        Options.Create(new KnowledgeAnswerAiOptions { Enabled = true, DataProcessingApproved = approved, ApiKey = "fixture-key" }),
        NullLogger<GeminiKnowledgeAnswer>.Instance);
    private static KnowledgeSearchHit Hit() => new("source-1", "Mục thử", 1, null, "Nguồn thử", "r1", Passage);
    private sealed class Handler(string output, string? repairedOutput = null) : HttpMessageHandler
    {
        public int Calls;
        public HttpStatusCode Status = HttpStatusCode.OK;
        public string? Body;
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            Calls++;
            Body = await request.Content!.ReadAsStringAsync(ct);
            return new(Status) { Content = JsonContent.Create(new
            {
                candidates = new[] { new { finishReason = "STOP", content = new { parts = new[] { new { text = Calls > 1 ? repairedOutput ?? output : output } } } } }
            }) };
        }
    }
}
