using CareSitter.Contracts.Services;
using CareSitter.ApiHost.Matching;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace CareSitter.ApiHost.Jobs;

/// <summary>
/// Hangfire background jobs for booking lifecycle automation.
/// Jobs move bookings to review first; escrow settlement only happens after
/// customer/admin confirmation or after the auto-confirm waiting period.
/// </summary>
public sealed class BookingJobsService
{
    private const int PaymentTimeoutMinutes = 15;
    private const int LateCheckinGraceMinutes = 10;
    private const int ShiftEndCheckoutGraceMinutes = 30;
    private const int AutoConfirmCheckoutHours = 24;

    private readonly IServiceProvider _services;
    private readonly ILogger<BookingJobsService> _logger;

    public BookingJobsService(IServiceProvider services, ILogger<BookingJobsService> logger)
    {
        _services = services;
        _logger = logger;
    }

    public async Task ExpirePendingPaymentsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-PaymentTimeoutMinutes);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();

        var expiredBookings = await db.Bookings
            .Where(b => b.Status == BookingStatus.PendingPayment && b.CreatedAt <= cutoff)
            .ToListAsync();

        var expiredSlotHolds = await db.CaregiverSlotHolds
            .Where(h => h.Status == "HELD" && h.ExpiresAt <= DateTimeOffset.UtcNow)
            .ToListAsync();
        foreach (var hold in expiredSlotHolds)
            hold.Release();

        if (expiredBookings.Count == 0 && expiredSlotHolds.Count == 0) return;

        _logger.LogInformation(
            "[BookingJobs] ExpirePendingPayments: found {Count} bookings to cancel", expiredBookings.Count);

        foreach (var booking in expiredBookings)
        {
            var result = booking.Cancel(
                userId: booking.CustomerId,
                role: "SYSTEM",
                reason: "AUTO_EXPIRED_PAYMENT_TIMEOUT",
                cancelledAt: DateTimeOffset.UtcNow);

            if (result.IsFailure)
            {
                _logger.LogWarning(
                    "[BookingJobs] Cannot cancel booking {Id}: {Error}", booking.Id, result.Error.Message);
                continue;
            }

            await hub.Clients
                .Group(CareTrackingHub.BookingGroup(booking.Id))
                .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                    booking.Id,
                    OldStatus: "pending_payment",
                    NewStatus: "cancelled",
                    ChangedAt: DateTimeOffset.UtcNow));
        }

        await db.SaveChangesAsync();
        _logger.LogInformation(
            "[BookingJobs] Cancelled {BookingCount} expired bookings and released {HoldCount} caregiver slot holds",
            expiredBookings.Count, expiredSlotHolds.Count);
    }

    public async Task AlertLateCheckinsAsync()
    {
        var warningCutoff = DateTimeOffset.UtcNow.AddMinutes(-LateCheckinGraceMinutes);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();

        var lateBookings = await db.Bookings
            .Where(b =>
                (b.Status == BookingStatus.CaregiverAccepted || b.Status == BookingStatus.CaregiverEnRoute)
                && b.ScheduledStart <= warningCutoff)
            .ToListAsync();

        foreach (var booking in lateBookings)
        {
            bool alreadyWarned = await db.TimelineEvents.AnyAsync(e =>
                e.BookingId == booking.Id && e.EventType == "LATE_CHECKIN");

            if (alreadyWarned) continue;

            _logger.LogWarning(
                "[BookingJobs] Late check-in for booking {Id} (scheduled {Start})",
                booking.Id, booking.ScheduledStart);

            var warnEvt = CareTimelineEvent.Create(
                booking.Id, booking.CaregiverId,
                eventType: "LATE_CHECKIN",
                title: "Caregiver chưa check-in đúng giờ",
                note: $"Ca bắt đầu lúc {booking.ScheduledStart:HH:mm} nhưng chưa check-in.",
                source: "SYSTEM");

            db.TimelineEvents.Add(warnEvt);

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
                    RecordedAt: DateTimeOffset.UtcNow));
        }

        if (lateBookings.Count > 0)
            await db.SaveChangesAsync();
    }

    public async Task AutoRequestCheckoutExpiredShiftsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-ShiftEndCheckoutGraceMinutes);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();
        var notifications = scope.ServiceProvider.GetRequiredService<IUserNotificationService>();

        var expiredShifts = await db.Bookings
            .Where(b => b.Status == BookingStatus.InProgress && b.ScheduledEnd <= cutoff)
            .ToListAsync();

        if (expiredShifts.Count == 0) return;

        _logger.LogInformation(
            "[BookingJobs] AutoRequestCheckout: found {Count} shifts to move to review", expiredShifts.Count);

        foreach (var booking in expiredShifts)
        {
            var oldStatus = ToApi(booking.Status);
            var requestedAt = DateTimeOffset.UtcNow;
            var result = booking.RequestSystemTimeoutCheckout(requestedAt);
            if (result.IsFailure)
            {
                _logger.LogWarning(
                    "[BookingJobs] Cannot move booking {Id} to checkout review: {Error}",
                    booking.Id, result.Error.Message);
                continue;
            }

            var evt = CareTimelineEvent.Create(
                booking.Id,
                booking.CaregiverId,
                eventType: "AUTO_CHECKOUT",
                title: "Ca chuyển sang chờ xác nhận tự động",
                note: "session_timeout_auto_checkout: ca đã quá giờ dự kiến, hệ thống chuyển sang chờ gia đình xác nhận.",
                source: "SYSTEM",
                metadata: "{\"reason\":\"session_timeout_auto_checkout\"}");
            db.TimelineEvents.Add(evt);

            await hub.Clients
                .Group(CareTrackingHub.BookingGroup(booking.Id))
                .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                    booking.Id,
                    OldStatus: oldStatus,
                    NewStatus: "checkout_pending_review",
                    ChangedAt: requestedAt));

            await notifications.NotifyAsync(new UserNotificationMessage(
                booking.CustomerId,
                "BOOKING",
                "Ca chăm sóc đã quá giờ dự kiến",
                "Hệ thống đã chuyển ca sang chờ gia đình xác nhận do quá giờ. Escrow chưa được giải ngân cho đến khi ca được xác nhận hoàn tất.",
                BookingNotificationData(booking)), CancellationToken.None);
        }

        await db.SaveChangesAsync();
        _logger.LogInformation("[BookingJobs] Moved {Count} expired shifts to checkout review", expiredShifts.Count);
    }

    public async Task AutoConfirmPendingCheckoutsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddHours(-AutoConfirmCheckoutHours);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();
        var wallet = scope.ServiceProvider.GetRequiredService<IWalletService>();
        var disputeLookup = scope.ServiceProvider.GetRequiredService<IDisputeLookupService>();
        var notifications = scope.ServiceProvider.GetRequiredService<IUserNotificationService>();

        var candidateIds = await db.Bookings.AsNoTracking()
            .Where(b => b.Status == BookingStatus.CheckoutPendingReview
                && b.CheckoutPendingReviewAt != null
                && b.CheckoutPendingReviewAt <= cutoff)
            .Select(b => b.Id)
            .ToListAsync();

        if (candidateIds.Count == 0) return;

        foreach (var bookingId in candidateIds)
        {
            if (await disputeLookup.HasOpenDisputeAsync(bookingId, CancellationToken.None))
                continue;

            await using var tx = await db.Database.BeginTransactionAsync();
            var booking = await db.Bookings.SingleOrDefaultAsync(b =>
                b.Id == bookingId && b.Status == BookingStatus.CheckoutPendingReview);
            if (booking is null)
            {
                await tx.RollbackAsync();
                continue;
            }
            if (booking.CaregiverId is not { } caregiverId)
            {
                await tx.RollbackAsync();
                continue;
            }

            if (await disputeLookup.HasOpenDisputeAsync(booking.Id, CancellationToken.None))
            {
                await tx.RollbackAsync();
                continue;
            }

            var oldStatus = ToApi(booking.Status);
            var result = booking.Complete();
            if (result.IsFailure)
            {
                await tx.RollbackAsync();
                _logger.LogWarning(
                    "[BookingJobs] Cannot auto-confirm checkout for booking {Id}: {Error}",
                    booking.Id, result.Error.Message);
                continue;
            }

            if (await disputeLookup.HasOpenDisputeAsync(booking.Id, CancellationToken.None))
            {
                await tx.RollbackAsync();
                continue;
            }

            var settleResult = await wallet.SettleAsync(
                booking.Id, caregiverId, booking.EscrowAmount, booking.PlatformFeeAmount,
                CancellationToken.None);
            if (settleResult.IsFailure)
            {
                await tx.RollbackAsync();
                _logger.LogWarning(
                    "[BookingJobs] Auto-confirm settle blocked for booking {Id}: {Error}",
                    booking.Id, settleResult.Error.Message);
                continue;
            }

            db.TimelineEvents.Add(CareTimelineEvent.Create(
                booking.Id,
                caregiverId,
                eventType: "CHECKOUT",
                title: "Ca tự động hoàn tất",
                note: $"Auto-confirm sau {AutoConfirmCheckoutHours}h chờ gia đình xác nhận, không có dispute mở.",
                source: "SYSTEM",
                metadata: "{\"reason\":\"auto_confirm_after_customer_timeout\"}"));

            await db.SaveChangesAsync();
            await tx.CommitAsync();

            await hub.Clients
                .Group(CareTrackingHub.BookingGroup(booking.Id))
                .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                    booking.Id,
                    OldStatus: oldStatus,
                    NewStatus: ToApi(booking.Status),
                    ChangedAt: DateTimeOffset.UtcNow));

            await notifications.NotifyAsync(new UserNotificationMessage(
                booking.CustomerId,
                "BOOKING",
                "Ca chăm sóc đã tự động hoàn tất",
                $"Ca đã được tự động xác nhận sau {AutoConfirmCheckoutHours}h chờ phản hồi và không có khiếu nại mở.",
                BookingNotificationData(booking)), CancellationToken.None);
        }
    }

    public async Task ExpandExpiredBookingOffersAsync()
    {
        await using var scope = _services.CreateAsyncScope();
        var matching = scope.ServiceProvider.GetRequiredService<IMatchingService>();
        var expanded = await matching.ExpandExpiredOffersAsync(CancellationToken.None);
        if (expanded > 0)
            _logger.LogInformation("[BookingJobs] Expanded {Count} expired caregiver offers", expanded);
    }

    private static string ToApi(BookingStatus status) => status switch
    {
        BookingStatus.Draft => "draft",
        BookingStatus.PendingPayment => "pending_payment",
        BookingStatus.Confirmed => "confirmed",
        BookingStatus.MatchingFailed => "matching_failed",
        BookingStatus.CaregiverAccepted => "caregiver_accepted",
        BookingStatus.CaregiverEnRoute => "caregiver_en_route",
        BookingStatus.InProgress => "in_progress",
        BookingStatus.CheckoutPendingReview => "checkout_pending_review",
        BookingStatus.Completed => "completed",
        BookingStatus.Crisis => "crisis",
        BookingStatus.Cancelled => "cancelled",
        BookingStatus.Disputed => "disputed",
        BookingStatus.Refunded => "refunded",
        _ => status.ToString().ToLowerInvariant()
    };

    private static IReadOnlyDictionary<string, string> BookingNotificationData(Booking booking) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };
}
