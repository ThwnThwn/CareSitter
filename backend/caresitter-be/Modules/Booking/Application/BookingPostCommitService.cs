using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Time;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Application;

internal sealed class BookingPostCommitService(
    IHubContext<CareTrackingHub> hub,
    BookingSyncService bookingSync,
    IUserNotificationService notifications,
    IPeopleLookupService people,
    IClock clock,
    ILogger<BookingPostCommitService> logger)
{
    public async Task RunAsync(string action, Func<Task> operation)
    {
        try
        {
            await operation();
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Booking committed, but post-commit action {PostCommitAction} failed.", action);
        }
    }

    public Task BroadcastStatusAsync(Guid bookingId, string oldStatus, string newStatus,
        CancellationToken ct) =>
        hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                bookingId, oldStatus, newStatus, DateTimeOffset.UtcNow), ct);

    public Task BroadcastAcceptedStatusAsync(Domain.Booking booking, string oldStatus,
        CancellationToken ct) =>
        hub.Clients.Groups(new[]
            {
                CareTrackingHub.BookingGroup(booking.Id),
                CareTrackingHub.CustomerGroup(booking.CustomerId)
            })
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id, oldStatus, "caregiver_accepted", DateTimeOffset.UtcNow), ct);

    public async Task PublishCustomerSyncEventAsync(Domain.Booking booking, CancellationToken ct)
    {
        var cursor = await bookingSync.GetCurrentCursorAsync(booking.CustomerId, ct);
        await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
            .SendAsync("BookingListSync", new BookingListSyncEvent(
                booking.Id,
                booking.SyncVersion,
                cursor,
                DateTimeOffset.UtcNow), ct);
    }

    public Task NotifyBookingUserAsync(Guid userId, Domain.Booking booking,
        string title, string body, CancellationToken ct) =>
        notifications.NotifyAsync(new UserNotificationMessage(
            userId,
            "BOOKING",
            title,
            body,
            BookingNotificationData(booking)), ct);

    public async Task NotifyCaregiverAsync(Domain.Booking booking,
        string title, string body, CancellationToken ct)
    {
        if (booking.CaregiverId is not { } caregiverId)
            return;

        var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return;

        await NotifyBookingUserAsync(caregiverUserId.Value, booking, title, body, ct);
    }

    public async Task NotifySosTargetsAsync(Domain.Booking booking, Guid raisedByUserId,
        CancellationToken ct)
    {
        var targets = new HashSet<Guid>();
        if (booking.CustomerId != raisedByUserId)
            targets.Add(booking.CustomerId);

        if (booking.CaregiverId is { } caregiverId)
        {
            var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
            if (caregiverUserId is not null && caregiverUserId.Value != raisedByUserId)
                targets.Add(caregiverUserId.Value);
        }

        foreach (var targetUserId in targets)
        {
            await notifications.NotifyAsync(new UserNotificationMessage(
                targetUserId,
                "SOS",
                "Có tín hiệu SOS",
                "Một tình huống khẩn cấp vừa được kích hoạt trong ca chăm sóc.",
                BookingNotificationData(booking)), ct);
        }
    }

    public async Task PublishOfferChangedAsync(Guid caregiverId, Guid bookingId,
        string changeType, CancellationToken ct)
    {
        var caregiverUserId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null) return;
        await hub.Clients.Group(CareTrackingHub.CaregiverGroup(caregiverUserId.Value))
            .SendAsync("BookingOfferChanged", new BookingOfferChangedEvent(
                bookingId, changeType, clock.UtcNow), ct);
    }

    private static IReadOnlyDictionary<string, string> BookingNotificationData(Domain.Booking booking) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = BookingStatusCodec.ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };
}
