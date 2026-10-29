using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.ApiHost.ChatFirestore;

public sealed record ChatFirestoreReconcileRequest(
    string ChatType, DateTime? AfterCreatedAt, Guid? AfterMessageId, int Limit = 100);

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/chat-firestore")]
public sealed class ChatFirestoreAdminController(
    ICurrentUser currentUser,
    IActiveAdminLookup activeAdmins,
    ChatFirestoreReconciler reconciler,
    IConfiguration configuration,
    IOptions<ChatFirestoreOptions> options) : ControllerBase
{
    [HttpPost("backfill")]
    public async Task<IActionResult> BackfillAsync([FromQuery] int batchSize = 200,
        CancellationToken ct = default)
    {
        if (!await AllowedAsync(ct)) return Forbid();
        if (!options.Value.ProjectionEnabled) return NotFound();
        return Ok(new { enqueued = await reconciler.EnqueueBackfillAsync(batchSize, ct) });
    }

    [HttpPost("reconcile")]
    public async Task<IActionResult> ReconcileAsync(
        [FromBody] ChatFirestoreReconcileRequest request, CancellationToken ct)
    {
        if (!await AllowedAsync(ct)) return Forbid();
        if (!options.Value.ProjectionEnabled) return NotFound();
        if (request.ChatType is not ("BOOKING" or "SUPPORT") ||
            request.AfterCreatedAt.HasValue != request.AfterMessageId.HasValue ||
            request.Limit is < 1 or > 100)
            return BadRequest();
        return Ok(await reconciler.ScanAsync(request.ChatType,
            request.AfterCreatedAt, request.AfterMessageId, request.Limit, ct));
    }

    [HttpGet("status")]
    public async Task<IActionResult> StatusAsync(CancellationToken ct)
    {
        if (!await AllowedAsync(ct)) return Forbid();
        if (!options.Value.ProjectionEnabled) return NotFound();
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            SELECT count(*) FILTER (WHERE delivered_at IS NULL),
                   count(*) FILTER (WHERE delivered_at IS NULL AND attempts > 0),
                   min(created_at) FILTER (WHERE delivered_at IS NULL),
                   count(*) FILTER (WHERE delivered_at IS NULL AND dead_letter_at IS NOT NULL)
            FROM public.chat_firestore_outbox
            """, connection);
        await using var reader = await command.ExecuteReaderAsync(ct);
        await reader.ReadAsync(ct);
        return Ok(new
        {
            pending = reader.GetInt64(0), retrying = reader.GetInt64(1),
            oldestPendingAt = reader.IsDBNull(2) ? (DateTime?)null : reader.GetDateTime(2),
            deadLetters = reader.GetInt64(3)
        });
    }

    [HttpPost("outbox/{eventId:long}/replay")]
    public async Task<IActionResult> ReplayAsync(long eventId, CancellationToken ct)
    {
        if (!await AllowedAsync(ct)) return Forbid();
        if (!options.Value.ProjectionEnabled) return NotFound();
        await using var connection = new NpgsqlConnection(
            configuration.GetConnectionString("CareSitter"));
        await connection.OpenAsync(ct);
        await using var command = new NpgsqlCommand("""
            UPDATE public.chat_firestore_outbox
            SET dead_letter_at = NULL, available_at = now(), attempts = 0,
                last_error = NULL
            WHERE id = @id AND delivered_at IS NULL
            """, connection);
        command.Parameters.AddWithValue("id", eventId);
        return await command.ExecuteNonQueryAsync(ct) == 1 ? Accepted() : NotFound();
    }

    private async Task<bool> AllowedAsync(CancellationToken ct) =>
        currentUser.UserId is { } userId &&
        await activeAdmins.IsActiveAdminAsync(userId, ct);
}
