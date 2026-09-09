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
/// Các Hangfire background jobs tự động xử lý vòng đời Booking.
///
/// Job 1 - ExpirePendingPayments (mỗi 1 phút):
///   Tự động hủy các booking ở trạng thái PendingPayment sau 15 phút không thanh toán.
///
/// Job 2 - AlertLateCheckins (mỗi 5 phút):
///   Phát hiện caregiver quá giờ chưa check-in → ghi timeline cảnh báo.
///
/// Job 3 - AutoCompleteExpiredShifts (mỗi 5 phút):
///   Tự động hoàn thành ca nếu quá giờ kết thúc 30 phút mà caregiver chưa checkout.
/// </summary>
public sealed class BookingJobsService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<BookingJobsService> _logger;

    public BookingJobsService(IServiceProvider services, ILogger<BookingJobsService> logger)
    {
        _services = services;
        _logger = logger;
    }

    // ════════════════════════════════════════════
    //  JOB 1: Auto-cancel booking hết hạn thanh toán
    // ════════════════════════════════════════════

    /// <summary>
    /// Quét booking ở PendingPayment quá 15 phút → tự động Cancel.
    /// Chạy mỗi 1 phút qua Hangfire recurring job.
    /// </summary>
    public async Task ExpirePendingPaymentsAsync()
    {
        const int timeoutMinutes = 15;
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-timeoutMinutes);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();

        var expiredBookings = await db.Bookings
            .Where(b => b.Status == BookingStatus.PendingPayment && b.CreatedAt <= cutoff)
            .ToListAsync();

        if (expiredBookings.Count == 0) return;

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

            // Broadcast trạng thái mới qua SignalR
            await hub.Clients
                .Group(CareTrackingHub.BookingGroup(booking.Id))
                .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                    booking.Id,
                    OldStatus: "pending_payment",
                    NewStatus: "cancelled",
                    ChangedAt: DateTimeOffset.UtcNow));
        }

        await db.SaveChangesAsync();
        _logger.LogInformation("[BookingJobs] Cancelled {Count} expired bookings", expiredBookings.Count);
    }

    // ════════════════════════════════════════════
    //  JOB 2: Cảnh báo caregiver quá giờ chưa check-in
    // ════════════════════════════════════════════

    /// <summary>
    /// Quét booking CaregiverAccepted/CaregiverEnRoute mà ScheduledStart đã qua 10 phút
    /// và chưa có GPS check-in → ghi timeline cảnh báo LATE_CHECKIN.
    /// Chạy mỗi 5 phút.
    /// </summary>
    public async Task AlertLateCheckinsAsync()
    {
        var warningCutoff = DateTimeOffset.UtcNow.AddMinutes(-10);

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
            // Tránh ghi nhiều lần: kiểm tra đã có LATE_CHECKIN event chưa
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

            // Notify qua SignalR
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

    // ════════════════════════════════════════════
    //  JOB 3: Auto-complete ca hết giờ
    // ════════════════════════════════════════════

    /// <summary>
    /// Quét booking InProgress mà ScheduledEnd đã qua 30 phút → tự động Complete.
    /// Giải ngân escrow cho caregiver qua WalletService.
    /// Chạy mỗi 5 phút.
    /// </summary>
    public async Task AutoCompleteExpiredShiftsAsync()
    {
        const int gracePeriodMinutes = 30;
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-gracePeriodMinutes);

        await using var scope = _services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<BookingDbContext>();
        var hub = scope.ServiceProvider.GetRequiredService<IHubContext<CareTrackingHub>>();
        var walletService = scope.ServiceProvider.GetService<IWalletService>();

        var expiredShifts = await db.Bookings
            .Where(b => b.Status == BookingStatus.InProgress && b.ScheduledEnd <= cutoff)
            .ToListAsync();

        if (expiredShifts.Count == 0) return;

        _logger.LogInformation(
            "[BookingJobs] AutoComplete: found {Count} shifts to complete", expiredShifts.Count);

        foreach (var booking in expiredShifts)
        {
            var result = booking.Complete();
            if (result.IsFailure)
            {
                _logger.LogWarning(
                    "[BookingJobs] Cannot auto-complete booking {Id}: {Error}", booking.Id, result.Error.Message);
                continue;
            }

            // Ghi timeline
            db.TimelineEvents.Add(CareTimelineEvent.Create(
                booking.Id, booking.CaregiverId,
                eventType: "AUTO_CHECKOUT",
                title: "Ca tự động kết thúc",
                note: $"Ca kết thúc tự động sau {gracePeriodMinutes} phút qua giờ dự kiến.",
                source: "SYSTEM"));

            // Giải ngân escrow
            if (walletService != null && booking.CaregiverId.HasValue)
            {
                try
                {
                    await walletService.SettleAsync(
                        booking.Id, booking.CaregiverId.Value,
                        booking.EscrowAmount, booking.PlatformFeeAmount,
                        CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex,
                        "[BookingJobs] Settle failed for booking {Id}", booking.Id);
                }
            }

            // Broadcast trạng thái mới
            await hub.Clients
                .Group(CareTrackingHub.BookingGroup(booking.Id))
                .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                    booking.Id,
                    OldStatus: "in_progress",
                    NewStatus: "completed",
                    ChangedAt: DateTimeOffset.UtcNow));
        }

        await db.SaveChangesAsync();
        _logger.LogInformation("[BookingJobs] Auto-completed {Count} expired shifts", expiredShifts.Count);
    }

    // ════════════════════════════════════════════
    //  JOB 4: Mở rộng offer matching đã hết hạn
    // ════════════════════════════════════════════

    /// <summary>
    /// Đánh dấu offer hết hạn và mời batch caregiver phù hợp tiếp theo.
    /// Chạy mỗi phút để booking không bị kẹt sau khi nhóm đầu không phản hồi.
    /// </summary>
    public async Task ExpandExpiredBookingOffersAsync()
    {
        await using var scope = _services.CreateAsyncScope();
        var matching = scope.ServiceProvider.GetRequiredService<IMatchingService>();
        var expanded = await matching.ExpandExpiredOffersAsync(CancellationToken.None);
        if (expanded > 0)
            _logger.LogInformation("[BookingJobs] Expanded {Count} expired caregiver offers", expanded);
    }
}
