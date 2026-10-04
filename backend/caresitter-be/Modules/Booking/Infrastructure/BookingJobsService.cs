using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Application.Sync;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Hangfire background jobs for booking lifecycle automation.
/// Jobs move bookings to review first; escrow settlement only happens after
/// customer/admin confirmation or after the auto-confirm waiting period.
/// </summary>
internal sealed class BookingJobsService : IBookingJobsService
{
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

    public async Task ReconcilePendingPaymentsAsync()
    {
        await using var scope = _services.CreateAsyncScope();
        var job = scope.ServiceProvider.GetRequiredService<IPaymentReconciliationJob>();
        await job.ExecuteAsync();
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
        var sync = scope.ServiceProvider.GetRequiredService<IBookingSyncService>();

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
            if (await db.CareTasks.AnyAsync(t => t.BookingId == booking.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED"))))
                booking.MarkNeedsReview();
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
            sync.WriteSyncEvent(booking, BookingSyncEventTypes.CheckoutRequested);
            await db.SaveChangesAsync();

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
        var disputeLookup = scope.ServiceProvider.GetRequiredService<IDisputeLookupService>();
        var notifications = scope.ServiceProvider.GetRequiredService<IUserNotificationService>();
        var sync = scope.ServiceProvider.GetRequiredService<IBookingSyncService>();

        var candidateIds = await db.Bookings.AsNoTracking()
            .Where(b => b.Status == BookingStatus.CheckoutPendingReview
                && !b.NeedsReview
                && !db.CareTasks.Any(t => t.BookingId == b.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED")))
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
                b.Id == bookingId && b.Status == BookingStatus.CheckoutPendingReview
                && !b.NeedsReview
                && !db.CareTasks.Any(t => t.BookingId == b.Id &&
                    (t.Status == "PENDING" || (t.IsRequired && t.Status == "SKIPPED"))));
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

            db.TimelineEvents.Add(CareTimelineEvent.Create(
                booking.Id,
                caregiverId,
                eventType: "CHECKOUT",
                title: "Ca tự động hoàn tất",
                note: $"Auto-confirm sau {AutoConfirmCheckoutHours}h chờ gia đình xác nhận, không có dispute mở.",
                source: "SYSTEM",
                metadata: "{\"reason\":\"auto_confirm_after_customer_timeout\"}"));

            sync.WriteSyncEvent(booking, BookingSyncEventTypes.Completed);
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

    /// <summary>
    /// Không còn caregiver phù hợp: hoàn toàn bộ escrow vào Ví CareSitter của
    /// khách, sau đó mới đóng booking thành REFUNDED. Job lặp lại an toàn khi
    /// lỗi tạm thời hoặc một worker bị dừng giữa hai database transaction.
    /// </summary>
    public async Task RefundUnmatchedBookingsAsync()
    {
        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var wallet = scope.ServiceProvider.GetRequiredService<IWalletService>();
        var disputeLookup = scope.ServiceProvider.GetRequiredService<IDisputeLookupService>();
        var sync = scope.ServiceProvider.GetRequiredService<IBookingSyncService>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();
        var notifications = scope.ServiceProvider.GetRequiredService<IUserNotificationService>();

        var bookingIds = await db.Bookings.AsNoTracking()
            .Where(x => x.Status == BookingStatus.MatchingFailed)
            .OrderBy(x => x.UpdatedAt)
            .Select(x => x.Id)
            .Take(100)
            .ToListAsync();

        foreach (var bookingId in bookingIds)
        {
            var snapshot = await db.Bookings.AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == bookingId && x.Status == BookingStatus.MatchingFailed);
            if (snapshot is null) continue;

            try
            {
                // Không giữ row lock của booking lúc PaymentsDbContext insert ledger:
                // FK ở schema payments sẽ chờ lock đó và gây deadlock giữa hai DbContext.
                var credited = await wallet.RefundToCustomerWalletAsync(
                    snapshot.Id, snapshot.CustomerId);
                if (credited.IsFailure)
                {
                    _logger.LogWarning("Could not credit customer wallet for unmatched booking {BookingId}: {Reason}",
                        snapshot.Id, credited.Error.Message);
                    continue;
                }

                await using var tx = await db.Database.BeginTransactionAsync();
                var booking = await db.Bookings.FromSqlInterpolated(
                    $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
                    .SingleOrDefaultAsync();
                if (booking is null || booking.Status == BookingStatus.Refunded)
                {
                    await tx.CommitAsync();
                    continue;
                }
                if (booking.Status != BookingStatus.MatchingFailed)
                {
                    await tx.CommitAsync();
                    continue;
                }

                var transitioned = booking.TransitionTo(BookingStatus.Refunded);
                if (transitioned.IsFailure)
                {
                    _logger.LogWarning("Could not mark unmatched booking {BookingId} refunded: {Reason}",
                        booking.Id, transitioned.Error.Message);
                    await tx.RollbackAsync();
                    continue;
                }

                sync.WriteSyncEvent(booking, "REFUNDED_NO_CAREGIVER");
                await db.SaveChangesAsync();
                await tx.CommitAsync();

                await hub.Clients.Group(CareTrackingHub.BookingGroup(booking.Id))
                    .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                        booking.Id, "matching_failed", "refunded", DateTimeOffset.UtcNow));
                await notifications.NotifyAsync(new UserNotificationMessage(
                    booking.CustomerId,
                    "PAYMENT",
                    "Đã hoàn tiền vào Ví CareSitter",
                    $"{booking.EscrowAmount:N0}đ đã được cộng vào Ví CareSitter vì chưa tìm được người chăm sóc phù hợp.",
                    new Dictionary<string, string>
                    {
                        ["bookingId"] = booking.Id.ToString(),
                        ["status"] = "refunded",
                        ["deepLink"] = $"/bookings/{booking.Id}"
                    }));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to refund unmatched booking {BookingId}", bookingId);
            }
        }
    }

    /// <summary>
    /// Releases caregiver earnings only after the booking-specific dispute window
    /// has elapsed. Booking validates maturity/disputes and Payments performs its
    /// own idempotent ledger transaction.
    /// </summary>
    public async Task ReleaseMatureSettlementsAsync()
    {
        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var wallet = scope.ServiceProvider.GetRequiredService<IWalletService>();
        var disputeLookup = scope.ServiceProvider.GetRequiredService<IDisputeLookupService>();
        var now = DateTimeOffset.UtcNow;

        var candidates = await db.Bookings.AsNoTracking()
            .Where(x => x.Status == BookingStatus.Completed &&
                        x.SettlementReleasedAt == null &&
                        x.ActualEnd != null &&
                        x.CaregiverId != null)
            .OrderBy(x => x.ActualEnd)
            .Take(100)
            .Select(x => new
            {
                x.Id,
                CaregiverId = x.CaregiverId!.Value,
                x.EscrowAmount,
                x.PlatformFeeAmount,
                ActualEnd = x.ActualEnd!.Value,
                x.DisputeWindowHours
            })
            .ToListAsync();

        foreach (var candidate in candidates.Where(x =>
                     x.ActualEnd.AddHours(x.DisputeWindowHours) <= now))
        {
            if (await disputeLookup.HasOpenDisputeAsync(candidate.Id, CancellationToken.None))
                continue;

            var result = await wallet.ReleaseMatureSettlementAsync(
                candidate.Id,
                candidate.CaregiverId,
                candidate.EscrowAmount,
                candidate.PlatformFeeAmount,
                now);
            if (result.IsFailure)
            {
                _logger.LogWarning(
                    "Could not release mature settlement for booking {BookingId}: {Reason}",
                    candidate.Id, result.Error.Message);
                continue;
            }

            var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == candidate.Id);
            if (booking is null || booking.SettlementReleasedAt is not null)
                continue;
            var marked = booking.MarkSettlementReleased(now);
            if (marked.IsFailure)
            {
                _logger.LogWarning(
                    "Settlement released but booking {BookingId} could not be stamped: {Reason}",
                    candidate.Id, marked.Error.Message);
                continue;
            }
            await db.SaveChangesAsync();
        }
    }

    private static string ToApi(BookingStatus status) => status switch
    {
        BookingStatus.Draft => "draft",
        BookingStatus.PendingPayment => "pending_payment",
        BookingStatus.PaymentReconciliationPending => "payment_reconciliation_pending",
        BookingStatus.NeedsManualReview => "needs_manual_review",
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

    private static IReadOnlyDictionary<string, string> BookingNotificationData(
        CareSitter.Modules.Booking.Domain.Booking booking) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };
}
