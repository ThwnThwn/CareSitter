using System.Text.Json;
using System.Text.Json.Nodes;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Domain;
using Microsoft.AspNetCore.Http;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class IdentityAuditLogger(
    IdentityDbContext db,
    ICurrentUser currentUser,
    IHttpContextAccessor httpContextAccessor) : IAuditLogger
{
    private const int MaxPayloadLength = 32_000;
    private static readonly string[] SensitiveFragments =
    [
        "password", "token", "secret", "hash", "authorization",
        "cccd", "accountnumber", "apikey", "connectionstring"
    ];

    public async Task WriteAsync(
        string action,
        string entityType,
        Guid entityId,
        object? before,
        object? after,
        CancellationToken ct = default)
    {
        var context = httpContextAccessor.HttpContext;
        var audit = AuditLog.Create(
            action,
            entityType,
            currentUser.UserId,
            entityId,
            afterData: SerializeSafe(after),
            ipAddress: context?.Connection.RemoteIpAddress?.ToString(),
            userAgent: context?.Request.Headers.UserAgent.ToString(),
            beforeData: SerializeSafe(before),
            actorRole: string.Join(',', currentUser.Roles.OrderBy(x => x)));

        if (audit.IsFailure) return;
        db.AuditLogs.Add(audit.Value);
        await db.SaveChangesAsync(ct);
    }

    private static string? SerializeSafe(object? value)
    {
        if (value is null) return null;

        var node = JsonSerializer.SerializeToNode(value, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
        Redact(node);
        var json = node?.ToJsonString();
        if (json is null || json.Length <= MaxPayloadLength) return json;

        return JsonSerializer.Serialize(new
        {
            truncated = true,
            originalLength = json.Length
        });
    }

    private static void Redact(JsonNode? node)
    {
        if (node is JsonObject obj)
        {
            foreach (var property in obj.ToList())
            {
                var normalized = property.Key.Replace("_", string.Empty)
                    .ToLowerInvariant();
                if (SensitiveFragments.Any(normalized.Contains))
                    obj[property.Key] = "[REDACTED]";
                else
                    Redact(property.Value);
            }
        }
        else if (node is JsonArray array)
        {
            foreach (var item in array) Redact(item);
        }
    }
}
