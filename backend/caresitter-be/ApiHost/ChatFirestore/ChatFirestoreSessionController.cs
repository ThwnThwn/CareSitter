using CareSitter.Contracts.Services;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.ChatFirestore;

[ApiController]
[Authorize]
[Route("api/v1/chat/firestore-session")]
public sealed class ChatFirestoreSessionController(
    ICurrentUser currentUser,
    IActiveUserLookup activeUsers,
    IOptions<ChatFirestoreOptions> options,
    ChatFirestoreClient firestore,
    ChatFirestoreAccessGate accessGate) : ControllerBase
{
    private static readonly TimeSpan SessionLifetime = TimeSpan.FromMinutes(5);
    [HttpPost]
    [EnableRateLimiting("auth-refresh")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> CreateAsync(CancellationToken ct)
    {
        if (!options.Value.ClientReadEnabled) return NotFound();
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (!await activeUsers.IsActiveWithAnyRoleAsync(userId, currentUser.Roles, ct))
            return Forbid();
        if (!await accessGate.CanIssueSessionAsync(ct))
        {
            Response.Headers.RetryAfter = "3";
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails
            {
                Title = "chat.firestore.projection_not_current",
                Detail = "Quyền chat đang đồng bộ. Vui lòng dùng lại API hiện tại."
            });
        }

        if (!long.TryParse(User.FindFirst("exp")?.Value, out var jwtExpiresAt) ||
            jwtExpiresAt <= DateTimeOffset.UtcNow.ToUnixTimeSeconds())
            return Unauthorized();
        var expiresAtMs = Math.Min(jwtExpiresAt,
            DateTimeOffset.UtcNow.Add(SessionLifetime).ToUnixTimeSeconds()) * 1000;

        var uid = userId.ToString("D");
        var token = await FirebaseAuth.GetAuth(firestore.AuthApp)
            .CreateCustomTokenAsync(uid, new Dictionary<string, object>
            {
                ["careSessionExpiresAtMs"] = expiresAtMs
            }, ct);
        Response.Headers.CacheControl = "no-store";
        return Ok(new { uid, customToken = token,
            projectId = options.Value.ProjectId, expiresAtMs });
    }
}
