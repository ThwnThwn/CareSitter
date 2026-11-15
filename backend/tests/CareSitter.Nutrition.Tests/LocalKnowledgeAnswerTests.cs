using System.Net;
using System.Net.Http.Json;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Logging.Abstractions;

namespace CareSitter.Nutrition.Tests;

public sealed class LocalKnowledgeAnswerTests
{
    [Fact]
    public async Task Ingredient_list_is_not_presented_as_health_benefits()
    {
        using var handler = new AnswerHandler(1);
        using var http = new HttpClient(handler) { BaseAddress = new Uri("http://127.0.0.1:11434") };
        var answer = new LocalKnowledgeAnswer(http, NullLogger<LocalKnowledgeAnswer>.Instance);
        var selected = await answer.SelectAsync("trái thơm tốt cho gì",
            [new("recipe", "Công thức", 42, "41", "Fixture", "1", "Chuẩn bị dứa, cà chua và hành.")],
            CancellationToken.None);

        Assert.Null(selected);
        Assert.Equal(0, handler.Calls);
    }

    [Fact]
    public async Task Selected_answer_returns_only_the_source_id()
    {
        using var handler = new AnswerHandler(1);
        using var http = new HttpClient(handler) { BaseAddress = new Uri("http://127.0.0.1:11434") };
        var answer = new LocalKnowledgeAnswer(http, NullLogger<LocalKnowledgeAnswer>.Instance);
        var selected = await answer.SelectAsync("chất xơ là gì",
            [new("reference", "Chất xơ", 42, "41", "Fixture", "1", "Đoạn thử nghiệm về chất xơ.")],
            CancellationToken.None);

        Assert.Equal("reference", selected);
        Assert.Equal(1, handler.Calls);
    }

    [Theory]
    [InlineData("{\"indices\":[2,1]}", "answered", "second,first")]
    [InlineData("{\"indices\":[]}", "insufficient_evidence", "")]
    [InlineData("{\"indices\":[99]}", "unavailable", "")]
    [InlineData("{\"indices\":[1,2,1,2]}", "unavailable", "")]
    [InlineData("{\"indices\":[\"1\"]}", "unavailable", "")]
    [InlineData("not json", "unavailable", "")]
    public async Task Multiple_answers_preserve_order_and_reject_invalid_model_output(string output, string status, string ids)
    {
        using var handler = new AnswerHandler(0) { Output = output };
        using var http = new HttpClient(handler) { BaseAddress = new Uri("http://127.0.0.1:11434") };
        var answer = new LocalKnowledgeAnswer(http, NullLogger<LocalKnowledgeAnswer>.Instance);
        var selected = await answer.SelectEvidenceAsync("chất xơ là gì", [
            new("first", "Mục 1", 1, null, "Fixture", "1", "Đoạn thử nghiệm thứ nhất về chất xơ."),
            new("second", "Mục 2", 2, null, "Fixture", "1", "Đoạn thử nghiệm thứ hai về chất xơ.")], CancellationToken.None);
        Assert.Equal(status, selected.Status);
        Assert.Equal(ids, string.Join(',', selected.ChunkIds));
    }

    [Fact]
    public async Task Cancelled_request_is_not_reported_as_insufficient_evidence()
    {
        using var handler = new AnswerHandler(0);
        using var http = new HttpClient(handler);
        var answer = new LocalKnowledgeAnswer(http, NullLogger<LocalKnowledgeAnswer>.Instance);
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            answer.SelectEvidenceAsync("chất xơ", [], new CancellationToken(true)));
    }

    [Fact]
    public async Task Offline_local_model_is_reported_as_unavailable()
    {
        using var handler = new AnswerHandler(0) { StatusCode = HttpStatusCode.ServiceUnavailable };
        using var http = new HttpClient(handler) { BaseAddress = new Uri("http://127.0.0.1:11434") };
        var answer = new LocalKnowledgeAnswer(http, NullLogger<LocalKnowledgeAnswer>.Instance);
        var result = await answer.SelectEvidenceAsync("chất xơ", [
            new("first", "Mục", 1, null, "Fixture", "1", "Đoạn thử nghiệm về chất xơ.")], CancellationToken.None);
        Assert.Equal("unavailable", result.Status);
        Assert.Empty(result.ChunkIds);
    }

    private sealed class AnswerHandler(int index) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        public string? Output { get; init; }
        public HttpStatusCode StatusCode { get; init; } = HttpStatusCode.OK;

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(new HttpResponseMessage(StatusCode)
            {
                Content = JsonContent.Create(new { response = Output ?? System.Text.Json.JsonSerializer.Serialize(new { index }) })
            });
        }
    }
}
