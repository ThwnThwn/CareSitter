using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Domain.Events;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingDomainOutboxDispatcher(
    BookingDbContext db,
    IHubContext<CareTrackingHub> hub,
    IBookingSyncService bookingSync,
    IUserNotificationService notifications,
    IPeopleLookupService people,
    IClock clock,
    IOptions<BookingSideEffectOptions> options,
    ILogger<BookingDomainOutboxDispatcher> logger)
{
    private readonly BookingSideEffectOptions _options = options.Value;

    public async Task<int> DispatchPendingAsync(CancellationToken ct)
    {
        var now = clock.UtcNow;
        var claimed = await ClaimAsync(now, ct);
        var processed = 0;
        foreach (var message in claimed)
        {
            try
            {
                await DispatchAsync(message, ct);
                message.MarkProcessed(clock.UtcNow);
                db.BookingDomainOutbox.Update(message);
                await db.SaveChangesAsync(ct);
                db.Entry(message).State = EntityState.Detached;
                processed++;
            }
            catch (Exception exception) when (exception is not OperationCanceledException)
            {
                var failedAt = clock.UtcNow;
                message.MarkFailed(exception.GetType().Name,
                    failedAt.AddSeconds(Math.Max(1, _options.RetryDelaySeconds)),
                    failedAt,
                    message.Attempts >= Math.Max(1, _options.MaxAttempts));
                db.BookingDomainOutbox.Update(message);
                await db.SaveChangesAsync(ct);
                db.Entry(message).State = EntityState.Detached;
                logger.LogWarning(exception,
                    "Booking domain outbox event {EventId} attempt {Attempt} failed.",
                    message.EventId, message.Attempts);
            }
        }

        return processed;
    }

    private async Task<IReadOnlyList<BookingDomainOutboxEvent>> ClaimAsync(
        DateTimeOffset now, CancellationToken ct)
    {
        var leaseUntil = now.AddSeconds(Math.Max(5, _options.LeaseSeconds));
        var claimToken = Guid.NewGuid();
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        var claimed = await db.BookingDomainOutbox.FromSqlInterpolated($$"""
            SELECT *
            FROM booking.booking_domain_outbox
            WHERE (status IN ('PENDING', 'FAILED') OR
                   (status = 'PROCESSING' AND lease_until IS NOT NULL AND lease_until <= {{now}}))
              AND available_at <= {{now}}
              AND (lease_until IS NULL OR lease_until <= {{now}})
            ORDER BY occurred_at, event_id
            LIMIT {{Math.Clamp(_options.BatchSize, 1, 200)}}
            FOR UPDATE SKIP LOCKED
            """).AsNoTracking().ToListAsync(ct);

        foreach (var message in claimed)
        {
            message.Claim(claimToken, now, leaseUntil);
            db.BookingDomainOutbox.Update(message);
        }
        if (claimed.Count > 0)
            await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        foreach (var message in claimed)
            db.Entry(message).State = EntityState.Detached;
        return claimed;
    }

    private async Task DispatchAsync(BookingDomainOutboxEvent message, CancellationToken ct)
    {
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == message.BookingId, ct);
        if (booking is null) return;

        switch (message.EventType)
        {
            case nameof(BookingStatusChanged):
                await DispatchStatusChangedAsync(message, booking, ct);
                break;
            case nameof(BookingSosRaised):
                await DispatchSosAsync(message, booking, ct);
                break;
            case nameof(BookingCheckedIn):
            case nameof(BookingCompletedDomainEvent):
                // The matching status event owns realtime/sync/notification delivery.
                break;
            default:
                throw new InvalidOperationException(
                    $"Unsupported booking outbox event '{message.EventType}'.");
        }
    }

    private async Task DispatchStatusChangedAsync(
        BookingDomainOutboxEvent message,
        Domain.Booking booking,
        CancellationToken ct)
    {
        using var payload = JsonDocument.Parse(message.Payload);
        var fromValue = Enum.Parse<BookingStatus>(
            payload.RootElement.GetProperty("From").GetString()!, ignoreCase: false);
        var toValue = Enum.Parse<BookingStatus>(
            payload.RootElement.GetProperty("To").GetString()!, ignoreCase: false);
        var from = BookingStatusCodec.ToApi(fromValue);
        var to = BookingStatusCodec.ToApi(toValue);
        var current = BookingStatusCodec.ToApi(booking.Status);

        var cursor = await bookingSync.GetCurrentCursorAsync(booking.CustomerId, ct);
        await hub.Clients.Group(CareTrackingHub.CustomerGroup(booking.CustomerId))
            .SendAsync("BookingListSync", new BookingListSyncEvent(
                booking.Id, booking.SyncVersion, cursor, clock.UtcNow), ct);

        // A delayed older event must not overwrite a newer client state.
        if (!string.Equals(current, to, StringComparison.Ordinal)) return;

        await hub.Clients.Groups(new[]
            {
                CareTrackingHub.BookingGroup(booking.Id),
                CareTrackingHub.CustomerGroup(booking.CustomerId)
            })
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id, from, to, message.OccurredAt), ct);

        await NotifyForStatusAsync(message, booking, to, ct);
    }

    private async Task NotifyForStatusAsync(
        BookingDomainOutboxEvent message,
        Domain.Booking booking,
        string status,
        CancellationToken ct)
    {
        switch (status)
        {
            case "confirmed":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Thanh toán thành công",
                    "Booking đã được xác nhận và đang tìm người chăm sóc phù hợp.", ct);
                await NotifyCaregiverAsync(message, booking,
                    "Bạn có lịch chăm sóc mới",
                    "Khách hàng đã thanh toán và đang chờ bạn xác nhận ca.", ct);
                break;
            case "caregiver_accepted":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Caregiver đã nhận lịch", "Lịch chăm sóc đã có người nhận.", ct);
                break;
            case "caregiver_en_route":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Caregiver đang di chuyển", "Caregiver đang trên đường đến ca chăm sóc.", ct);
                break;
            case "in_progress":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Caregiver đã check-in", "Ca chăm sóc đã bắt đầu.", ct);
                break;
            case "checkout_pending_review":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Ca chăm sóc chờ xác nhận", "Caregiver đã yêu cầu hoàn tất ca chăm sóc.", ct);
                break;
            case "completed":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Ca chăm sóc đã hoàn tất", "Ca chăm sóc đã được xác nhận hoàn tất.", ct);
                await NotifyCaregiverAsync(message, booking,
                    "Ca chăm sóc đã hoàn tất", "Khách hàng đã xác nhận hoàn tất ca chăm sóc.", ct);
                break;
            case "cancelled":
                if (string.Equals(booking.CancelledByRole, "CUSTOMER", StringComparison.Ordinal))
                {
                    await NotifyCaregiverAsync(message, booking,
                        "Lịch chăm sóc đã bị hủy", "Khách hàng đã hủy lịch chăm sóc.", ct);
                }
                else
                {
                    var paymentRejected = booking.CancelReason?.StartsWith(
                        "PAYMENT_MANUAL_REJECTED", StringComparison.Ordinal) == true;
                    await NotifyAsync(message, booking.CustomerId, booking,
                        paymentRejected ? "Thanh toán không được chấp nhận" : "Booking đã bị hủy",
                        paymentRejected
                            ? "Booking đã bị hủy sau khi đối soát thanh toán."
                            : "Booking đã bị hủy vì thanh toán không hoàn tất.", ct);
                }
                break;
            case "matching_failed":
                await NotifyAsync(message, booking.CustomerId, booking,
                    "Chưa tìm thấy caregiver", "Hệ thống chưa tìm được caregiver phù hợp cho lịch này.", ct);
                break;
        }
    }

    private async Task DispatchSosAsync(
        BookingDomainOutboxEvent message,
        Domain.Booking booking,
        CancellationToken ct)
    {
        using var payload = JsonDocument.Parse(message.Payload);
        Guid? raisedBy = null;
        if (payload.RootElement.TryGetProperty("RaisedByUserId", out var value) &&
            value.ValueKind == JsonValueKind.String && value.TryGetGuid(out var parsed))
            raisedBy = parsed;

        if (booking.CustomerId != raisedBy)
            await NotifyAsync(message, booking.CustomerId, booking,
                "Có tín hiệu SOS", "Một tình huống khẩn cấp vừa được kích hoạt trong ca chăm sóc.", ct,
                "SOS");
        var caregiverUserId = await CaregiverUserIdAsync(booking, ct);
        if (caregiverUserId is { } caregiver && caregiver != raisedBy)
            await NotifyAsync(message, caregiver, booking,
                "Có tín hiệu SOS", "Một tình huống khẩn cấp vừa được kích hoạt trong ca chăm sóc.", ct,
                "SOS");
    }

    private async Task NotifyCaregiverAsync(
        BookingDomainOutboxEvent message,
        Domain.Booking booking,
        string title,
        string body,
        CancellationToken ct)
    {
        var caregiverUserId = await CaregiverUserIdAsync(booking, ct);
        if (caregiverUserId is { } userId)
            await NotifyAsync(message, userId, booking, title, body, ct);
    }

    private async Task<Guid?> CaregiverUserIdAsync(Domain.Booking booking, CancellationToken ct) =>
        booking.CaregiverId is { } caregiverId
            ? await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct)
            : null;

    private Task NotifyAsync(
        BookingDomainOutboxEvent message,
        Guid userId,
        Domain.Booking booking,
        string title,
        string body,
        CancellationToken ct,
        string type = "BOOKING") =>
        notifications.NotifyAsync(new UserNotificationMessage(
            userId,
            type,
            title,
            body,
            new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["status"] = BookingStatusCodec.ToApi(booking.Status),
                ["deepLink"] = $"/bookings/{booking.Id}"
            },
            RecipientEventId(message.EventId, userId),
            message.OccurredAt), ct);

    private static Guid RecipientEventId(Guid eventId, Guid recipientId)
    {
        Span<byte> input = stackalloc byte[32];
        eventId.TryWriteBytes(input[..16]);
        recipientId.TryWriteBytes(input[16..]);
        var hash = SHA256.HashData(input);
        return new Guid(hash[..16]);
    }
}
