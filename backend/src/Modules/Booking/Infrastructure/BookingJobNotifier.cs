using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.AspNetCore.SignalR;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingJobNotifier(IHubContext<CareTrackingHub> hub, IUserNotificationService notifications) : IBookingJobNotifier
{
    public async Task LateCheckinAsync(BookingEntity booking, CancellationToken ct = default)
    {
        await hub.Clients
            .Group(CareTrackingHub.BookingGroup(booking.Id))
            .SendAsync("TimelineEventAdded", new TimelineEventAddedEvent(
                booking.Id,
                booking.CaregiverId,
                EventType: "LATE_CHECKIN",
                Title: "Caregiver chưa check-in đúng giờ",
                Note: $"Ca bắt đầu lúc {booking.ScheduledStart:HH:mm} nhưng chưa check-in.",
                Latitude: null,
                Longitude: null,
                RecordedAt: DateTimeOffset.UtcNow), ct);

    }

    public async Task CheckoutRequestedAsync(BookingJobChange change, CancellationToken ct = default)
    {
        var booking = change.Booking;
        var oldStatus = change.OldStatus;
        var requestedAt = change.ChangedAt;
        await hub.Clients
            .Group(CareTrackingHub.BookingGroup(booking.Id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id,
                OldStatus: oldStatus,
                NewStatus: "checkout_pending_review",
                ChangedAt: requestedAt), ct);

        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId,
            "BOOKING",
            "Ca chăm sóc đã quá giờ dự kiến",
            "Hệ thống đã chuyển ca sang chờ gia đình xác nhận do quá giờ. Escrow chưa được giải ngân cho đến khi ca được xác nhận hoàn tất.",
            BookingNotificationData(booking)), ct);
    }

    public async Task AutoConfirmedAsync(BookingJobChange change, CancellationToken ct = default)
    {
        var booking = change.Booking;
        var oldStatus = change.OldStatus;
        await hub.Clients
            .Group(CareTrackingHub.BookingGroup(booking.Id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id,
                OldStatus: oldStatus,
                NewStatus: BookingStatusPresenter.ToApi(booking.Status),
                ChangedAt: DateTimeOffset.UtcNow), ct);

        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId,
            "BOOKING",
            "Ca chăm sóc đã tự động hoàn tất",
            $"Ca đã được tự động xác nhận sau {BookingLifecyclePolicy.AutoConfirmCheckoutHours}h chờ phản hồi và không có khiếu nại mở.",
            BookingNotificationData(booking)), ct);
    }

    public async Task RefundedAsync(
        BookingEntity booking,
        OriginalPaymentRefundOutcome outcome,
        CancellationToken ct = default)
    {
        await hub.Clients.Group(CareTrackingHub.BookingGroup(booking.Id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id, "matching_failed", "refunded", DateTimeOffset.UtcNow), ct);
        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId, "PAYMENT", "Đã hoàn tiền",
            $"{outcome.Amount:N0}đ đã được hoàn về phương thức thanh toán {outcome.Provider} ban đầu.",
            BookingNotificationData(booking)), ct);
    }

    private static IReadOnlyDictionary<string, string> BookingNotificationData(BookingEntity booking, CancellationToken ct = default) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = BookingStatusPresenter.ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };
}
