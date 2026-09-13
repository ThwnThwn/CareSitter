using CareSitter.Contracts.Services;
using CareSitter.ApiHost.Matching;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Jobs;

/// <summary>
/// Hangfire background jobs for booking lifecycle automation.
/// Jobs move bookings to review first; escrow settlement only happens after
/// customer/admin confirmation or after the auto-confirm waiting period.
/// </summary>
public sealed class BookingJobsService
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
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var paymentsDb = scope.ServiceProvider.GetRequiredService<PaymentsDbContext>();
        var vnPay = scope.ServiceProvider.GetRequiredService<IVNPayService>();
        var vnPayOptions = scope.ServiceProvider.GetRequiredService<IOptions<VNPayOptions>>().Value;
        var finalizer = scope.ServiceProvider.GetRequiredService<IPaymentFinalizationService>();
        var bookingSync = scope.ServiceProvider.GetRequiredService<BookingSyncService>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();
        var now = DateTimeOffset.UtcNow;
        var dueBookingIds = await db.Bookings.AsNoTracking()
            .Where(b => (b.Status == BookingStatus.PendingPayment && b.PaymentDeadline <= now) ||
                b.Status == BookingStatus.PaymentReconciliationPending)
            .Select(b => b.Id)
            .Take(100)
            .ToListAsync();

        foreach (var bookingId in dueBookingIds)
        {
            var succeededIntent = await paymentsDb.PaymentIntents
                .Where(x => x.BookingId == bookingId && x.Provider == "VNPAY")
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync(x => x.Status == "SUCCEEDED");

            if (succeededIntent is not null)
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(succeededIntent.Id,
                    succeededIntent.ProviderTransactionId, succeededIntent.ResponsePayload,
                    PaymentFinalizationSource.ReconciliationJob);
                if (!finalized.Succeeded)
                    _logger.LogWarning("Could not finalize successful VNPay intent {IntentId}: {Message}",
                        succeededIntent.Id, finalized.Message);
                continue;
            }

            var intent = await paymentsDb.PaymentIntents
                .Where(x => x.BookingId == bookingId && x.Provider == "VNPAY" && x.Status == "PENDING")
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync();

            if (intent is null)
            {
                await CancelExpiredBookingAsync(db, bookingSync, hub, bookingId, now);
                continue;
            }
            if (intent.NextReconciliationAt is { } next && next > now) continue;

            await MoveToReconciliationAsync(db, bookingSync, hub, bookingId, now);
            VNPayQueryResult query;
            try
            {
                query = await vnPay.QueryTransactionAsync(intent, vnPayOptions);
            }
            catch (Exception ex)
            {
                query = new(VNPayQueryState.Unknown, null, "NETWORK", null, "{}", ex.Message);
            }

            if (query.State == VNPayQueryState.Succeeded)
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id, query.TransactionId,
                    query.RawPayload, PaymentFinalizationSource.ReconciliationJob);
                if (!finalized.Succeeded)
                    _logger.LogWarning("Could not finalize reconciled VNPay intent {IntentId}: {Message}",
                        intent.Id, finalized.Message);
                continue;
            }
            if (query.State is VNPayQueryState.Failed or VNPayQueryState.NotFound)
            {
                await CloseDefinitiveFailureAsync(db, bookingSync, hub, bookingId,
                    intent.Id, query, now);
                continue;
            }

            var startedAt = intent.ReconciliationStartedAt ?? now;
            var reachedLimit = intent.ReconciliationAttempts + 1 >= vnPayOptions.MaxReconciliationAttempts ||
                now - startedAt >= TimeSpan.FromMinutes(vnPayOptions.ReconciliationWindowMinutes);
            intent.RecordReconciliationAttempt(now,
                reachedLimit ? null : now.AddMinutes(intent.ReconciliationAttempts switch { 0 => 1, 1 => 3, _ => 6 }),
                query.Message ?? $"VNPay state: {query.State}");
            if (reachedLimit)
                intent.SetManualReviewReason(intent.LastReconciliationError ?? "VNPay query inconclusive");
            await paymentsDb.SaveChangesAsync();
            if (reachedLimit)
                await MoveToManualReviewAsync(db, bookingSync, hub, bookingId, now);
        }
    }

    private static async Task MoveToReconciliationAsync(BookingDbContext db, BookingSyncService sync,
        IHubContext<CareTrackingHub> hub, Guid bookingId, DateTimeOffset now)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleOrDefaultAsync();
        if (booking?.Status != BookingStatus.PendingPayment) return;
        booking.BeginPaymentReconciliation();
        sync.WriteSyncEvent(booking, "PAYMENT_RECONCILIATION_STARTED");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync(
            "BookingStatusChanged", new BookingStatusChangedEvent(bookingId, "pending_payment",
                "payment_reconciliation_pending", now));
    }

    private static async Task CancelExpiredBookingAsync(BookingDbContext db, BookingSyncService sync,
        IHubContext<CareTrackingHub> hub, Guid bookingId, DateTimeOffset now)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleOrDefaultAsync();
        if (booking is null || booking.Status is not (BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending)) return;
        var oldStatus = ToApi(booking.Status);
        var result = booking.Cancel(booking.CustomerId, "SYSTEM", "AUTO_EXPIRED_PAYMENT_RECONCILED", now);
        if (result.IsFailure) return;
        var holds = await db.CaregiverSlotHolds.Where(x => x.BookingId == bookingId && x.Status == "HELD").ToListAsync();
        foreach (var hold in holds) hold.Release();
        sync.WriteSyncEvent(booking, "PAYMENT_EXPIRED");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync(
            "BookingStatusChanged", new BookingStatusChangedEvent(bookingId, oldStatus, "cancelled", now));
    }

    private static async Task CloseDefinitiveFailureAsync(
        BookingDbContext db,
        BookingSyncService sync,
        IHubContext<CareTrackingHub> hub,
        Guid bookingId,
        Guid intentId,
        VNPayQueryResult query,
        DateTimeOffset now)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleOrDefaultAsync();
        if (booking is null || booking.Status is not
            (BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending))
            return;

        var closedStatus = query.State == VNPayQueryState.NotFound ? "EXPIRED" : "FAILED";
        var error = query.Message ?? $"VNPay state: {query.State}";
        var updated = await db.Database.ExecuteSqlInterpolatedAsync($$"""
            UPDATE payments.payment_intents
            SET status = {{closedStatus}}, response_payload = CAST({{query.RawPayload}} AS jsonb),
                reconciliation_attempts = reconciliation_attempts + 1,
                reconciliation_started_at = COALESCE(reconciliation_started_at, {{now}}),
                last_reconciliation_at = {{now}}, next_reconciliation_at = NULL,
                last_reconciliation_error = {{error}}, finalized_source = 'ReconciliationJob',
                updated_at = now()
            WHERE id = {{intentId}} AND status = 'PENDING'
            """);
        if (updated == 0) return;

        var oldStatus = ToApi(booking.Status);
        var cancelled = booking.Cancel(
            booking.CustomerId, "SYSTEM", "AUTO_EXPIRED_PAYMENT_RECONCILED", now);
        if (cancelled.IsFailure) return;
        var holds = await db.CaregiverSlotHolds
            .Where(x => x.BookingId == bookingId && x.Status == "HELD").ToListAsync();
        foreach (var hold in holds) hold.Release();
        sync.WriteSyncEvent(booking, "PAYMENT_EXPIRED");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync(
            "BookingStatusChanged", new BookingStatusChangedEvent(bookingId, oldStatus, "cancelled", now));
    }

    private static async Task MoveToManualReviewAsync(BookingDbContext db, BookingSyncService sync,
        IHubContext<CareTrackingHub> hub, Guid bookingId, DateTimeOffset now)
    {
        await using var tx = await db.Database.BeginTransactionAsync();
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE").SingleOrDefaultAsync();
        if (booking?.Status != BookingStatus.PaymentReconciliationPending) return;
        booking.MarkPaymentNeedsManualReview();
        sync.WriteSyncEvent(booking, "PAYMENT_NEEDS_MANUAL_REVIEW");
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync(
            "BookingStatusChanged", new BookingStatusChangedEvent(bookingId,
                "payment_reconciliation_pending", "needs_manual_review", now));
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

    private static IReadOnlyDictionary<string, string> BookingNotificationData(Booking booking) =>
        new Dictionary<string, string>
        {
            ["bookingId"] = booking.Id.ToString(),
            ["status"] = ToApi(booking.Status),
            ["deepLink"] = $"/bookings/{booking.Id}"
        };
}
