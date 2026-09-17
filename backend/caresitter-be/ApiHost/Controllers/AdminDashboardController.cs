using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.ApiHost.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/dashboard")]
public sealed class AdminDashboardController(
    BookingDbContext bookingDb,
    PeopleDbContext peopleDb,
    PaymentsDbContext paymentsDb,
    SupportDbContext supportDb,
    IdentityDbContext identityDb) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var vietnamOffset = TimeSpan.FromHours(7);
        var localNow = DateTimeOffset.UtcNow.ToOffset(vietnamOffset);
        var localStart = new DateTimeOffset(localNow.Year, localNow.Month, localNow.Day,
            0, 0, 0, vietnamOffset).ToUniversalTime();
        var localEnd = localStart.AddDays(1);

        var bookingsToday = await bookingDb.Bookings.AsNoTracking()
            .CountAsync(x => x.ScheduledStart >= localStart && x.ScheduledStart < localEnd, ct);
        var pendingKyc = await peopleDb.CaregiverProfiles.AsNoTracking()
            .CountAsync(x => x.DeletedAt == null && x.KycStatus == "PENDING", ct);
        var pendingPayouts = await paymentsDb.PayoutRequests.AsNoTracking()
            .CountAsync(x => x.Status == "PENDING", ct);
        var openTickets = await supportDb.SupportTickets.AsNoTracking()
            .CountAsync(x => x.Status == "NEW" || x.Status == "IN_PROGRESS", ct);
        var openDisputes = await supportDb.Disputes.AsNoTracking()
            .CountAsync(x => x.Status == "OPEN" || x.Status == "INVESTIGATING", ct);
        var manualPayments = await paymentsDb.PaymentIntents.AsNoTracking()
            .CountAsync(x => x.Status == "PENDING" && x.ManualReviewReason != null, ct);
        var activeUsers = await identityDb.Users.AsNoTracking()
            .CountAsync(x => x.DeletedAt == null && x.Status == "ACTIVE", ct);

        var bookingGroups = await bookingDb.Bookings.AsNoTracking()
            .GroupBy(x => x.Status)
            .Select(x => new { Status = x.Key, Count = x.Count() })
            .ToListAsync(ct);

        var workItems = new List<AdminWorkItem>();

        var paymentItems = await paymentsDb.PaymentIntents.AsNoTracking()
            .Where(x => x.Status == "PENDING" && x.ManualReviewReason != null)
            .OrderBy(x => x.ReconciliationStartedAt)
            .Take(5)
            .Select(x => new { x.Id, x.BookingId, x.Amount, x.ReconciliationStartedAt, x.CreatedAt })
            .ToListAsync(ct);
        workItems.AddRange(paymentItems.Select(x => new AdminWorkItem(
            "PAYMENT", x.Id, "Đối soát thanh toán", $"Booking {x.BookingId} · {x.Amount:N0} đ",
            "NEEDS_REVIEW", x.ReconciliationStartedAt ?? x.CreatedAt)));

        var kycItems = await peopleDb.CaregiverProfiles.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "PENDING")
            .OrderBy(x => x.UpdatedAt)
            .Take(5)
            .Select(x => new { x.Id, x.FullName, x.UpdatedAt })
            .ToListAsync(ct);
        workItems.AddRange(kycItems.Select(x => new AdminWorkItem(
            "KYC", x.Id, "Hồ sơ KYC chờ duyệt", x.FullName ?? "Caregiver chưa cập nhật tên",
            "PENDING", x.UpdatedAt)));

        var payoutItems = await paymentsDb.PayoutRequests.AsNoTracking()
            .Where(x => x.Status == "PENDING")
            .OrderBy(x => x.RequestedAt)
            .Take(5)
            .Select(x => new { x.Id, x.AccountHolderName, x.Amount, x.RequestedAt })
            .ToListAsync(ct);
        workItems.AddRange(payoutItems.Select(x => new AdminWorkItem(
            "PAYOUT", x.Id, "Yêu cầu rút tiền", $"{x.AccountHolderName} · {x.Amount:N0} đ",
            "PENDING", x.RequestedAt)));

        var ticketItems = await supportDb.SupportTickets.AsNoTracking()
            .Where(x => x.Status == "NEW" || x.Status == "IN_PROGRESS")
            .OrderByDescending(x => x.Priority == "CRITICAL")
            .ThenBy(x => x.CreatedAt)
            .Take(5)
            .Select(x => new { x.Id, x.Title, x.Type, x.Priority, x.Status, x.CreatedAt })
            .ToListAsync(ct);
        workItems.AddRange(ticketItems.Select(x => new AdminWorkItem(
            "SUPPORT", x.Id, x.Title, $"{x.Type} · {x.Priority}", x.Status, x.CreatedAt)));

        var disputeItems = await supportDb.Disputes.AsNoTracking()
            .Where(x => x.Status == "OPEN" || x.Status == "INVESTIGATING")
            .OrderBy(x => x.OpenedAt)
            .Take(5)
            .Select(x => new { x.Id, x.BookingId, x.Reason, x.Status, x.OpenedAt })
            .ToListAsync(ct);
        workItems.AddRange(disputeItems.Select(x => new AdminWorkItem(
            "DISPUTE", x.Id, x.Reason ?? "Khiếu nại booking", $"Booking {x.BookingId}",
            x.Status, x.OpenedAt)));

        return Ok(new
        {
            generatedAt = DateTimeOffset.UtcNow,
            metrics = new
            {
                bookingsToday,
                pendingKyc,
                pendingPayouts,
                openTickets,
                openDisputes,
                manualPayments,
                activeUsers
            },
            bookingStatuses = bookingGroups.ToDictionary(x =>
                ToApiStatus(x.Status), x => x.Count),
            workItems = workItems.OrderBy(x => x.CreatedAt).Take(12)
        });
    }

    private static string ToApiStatus(BookingStatus status) => status switch
    {
        BookingStatus.PendingPayment => "pending_payment",
        BookingStatus.PaymentReconciliationPending => "payment_reconciliation_pending",
        BookingStatus.NeedsManualReview => "needs_manual_review",
        BookingStatus.CaregiverAccepted => "caregiver_accepted",
        BookingStatus.CaregiverEnRoute => "caregiver_en_route",
        BookingStatus.InProgress => "in_progress",
        BookingStatus.CheckoutPendingReview => "checkout_pending_review",
        BookingStatus.MatchingFailed => "matching_failed",
        _ => status.ToString().ToLowerInvariant()
    };
}

public sealed record AdminWorkItem(
    string Type,
    Guid Id,
    string Title,
    string Subtitle,
    string Status,
    DateTimeOffset CreatedAt);
