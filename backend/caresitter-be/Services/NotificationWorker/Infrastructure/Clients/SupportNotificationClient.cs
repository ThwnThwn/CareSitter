using System.Net.Http.Json;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.NotificationWorker.Application.Ports;

namespace CareSitter.NotificationWorker.Infrastructure.Clients;

/// <summary>Calls service-key authenticated Support endpoints over the internal network.</summary>
public sealed class SupportNotificationClient(HttpClient http) : INotificationDeliveryClient
{
    /// <summary>Fetches current delivery input after an atomic claim; responses must never be logged.</summary>
    public async Task<DeliveryClaim> ClaimAsync(Guid eventId, Guid notificationId, Guid recipientId, string channel, CancellationToken ct)
    {
        using var response = await http.PostAsJsonAsync("internal/messaging/notifications/claim",
            new { eventId, notificationId, recipientId, channel }, ct);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<DeliveryClaim>(ct) ?? throw new IOException("Empty claim response.");
    }

    /// <summary>Reports a provider result; a lost response is safely retried through the next claim.</summary>
    public async Task<bool> CompleteAsync(Guid eventId, string channel, Guid token, bool success, string? failure, CancellationToken ct)
    {
        using var response = await http.PostAsJsonAsync("internal/messaging/notifications/complete",
            new { eventId, channel, claimToken = token, succeeded = success, failure }, ct);
        return response.IsSuccessStatusCode;
    }
}
