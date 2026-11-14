using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.ApiHost.Nutrition;

public sealed class NutritionKnowledgeOptions
{
    public bool Enabled { get; set; }
    public bool GeneralKnowledgeEnabled { get; set; }
    public string? LocalDemoLanAddress { get; set; }
}

public sealed record NutritionKnowledgeHitResponse(string ChunkId, string Heading, int PdfPage,
    string? PrintedPage, string SourceTitle, string SourceRevisionId, string? Excerpt = null);
public sealed record NutritionKnowledgeAnswerBlockResponse(string Text, IReadOnlyList<string> ChunkIds);
public sealed record NutritionKnowledgeSearchResponse(string Query,
    IReadOnlyList<NutritionKnowledgeHitResponse> Results, string? AnswerChunkId = null, bool LocalDemo = false,
    IReadOnlyList<string>? AnswerChunkIds = null, string? AnswerStatus = null,
    IReadOnlyList<NutritionKnowledgeAnswerBlockResponse>? AnswerBlocks = null, string? AnswerProvider = null,
    bool GeneralKnowledge = false, bool ReferenceKnowledge = false);

[ApiController, Authorize(Roles = "CUSTOMER")]
[Route("api/v1/nutrition/knowledge")]
public sealed class NutritionKnowledgeController(INutritionGateway gateway,
    IOptions<NutritionKnowledgeOptions> options, IHostEnvironment environment) : ControllerBase
{
    [HttpGet, EnableRateLimiting("nutrition-knowledge"), ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Get([FromQuery] string? q, CancellationToken ct)
    {
        if (!options.Value.Enabled)
            return StatusCode(503, new { code = "NUTRITION_KNOWLEDGE_UNAVAILABLE", message = "Tra cứu dinh dưỡng chưa được mở trên máy chủ." });
        var query = q?.Trim() ?? "";
        if (query.Length is < 3 or > 160)
            return BadRequest(new { code = "NUTRITION_KNOWLEDGE_QUERY_INVALID", message = "Nhập từ 3 đến 160 ký tự để tra cứu." });
        var localDemo = IsDirectDemoConnection();
        var result = await gateway.KnowledgeAsync(query, ct, localDemo,
            !localDemo && options.Value.GeneralKnowledgeEnabled);
        if (result.StatusCode == 200) return Ok(result.Body);
        if (result.StatusCode == 503)
            return StatusCode(503, new { code = "NUTRITION_KNOWLEDGE_UNAVAILABLE", message = "Chưa tải được tài liệu dinh dưỡng." });
        return StatusCode(result.StatusCode, result.Body);
    }

    private bool IsDirectDemoConnection()
    {
        if (!environment.IsDevelopment() ||
            !IPAddress.TryParse(options.Value.LocalDemoLanAddress, out var configured) ||
            configured.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork ||
            Request.Host.Host != configured.ToString() ||
            Request.Headers.Keys.Any(key => key.Equals("Forwarded", StringComparison.OrdinalIgnoreCase) ||
                key.StartsWith("X-Forwarded-", StringComparison.OrdinalIgnoreCase) ||
                key.StartsWith("X-Original-", StringComparison.OrdinalIgnoreCase)))
            return false;
        var local = HttpContext.Connection.LocalIpAddress?.MapToIPv4();
        var remote = HttpContext.Connection.RemoteIpAddress;
        if (!configured.Equals(local) || remote is null ||
            (remote.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork && !remote.IsIPv4MappedToIPv6))
            return false;
        var server = configured.GetAddressBytes();
        var peer = remote.MapToIPv4().GetAddressBytes();
        var privateAddress = server[0] == 10 || (server[0] == 192 && server[1] == 168) ||
            (server[0] == 172 && server[1] is >= 16 and <= 31);
        return privateAddress && server.AsSpan(0, 3).SequenceEqual(peer.AsSpan(0, 3));
    }
}
