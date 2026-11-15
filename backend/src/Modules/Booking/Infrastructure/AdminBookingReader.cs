using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class AdminBookingReader(BookingDbContext db) : IAdminBookingReader
{
    private static readonly AdminStatusDescriptor[] StatusDescriptors =
        Enum.GetValues<BookingStatus>()
            .Select(status => new AdminStatusDescriptor(
                ToApiStatus(status), StatusLabel(status), StatusTone(status)))
            .ToArray();

    public async Task<AdminBookingSnapshot> GetDashboardSnapshotAsync(
        DateTimeOffset scheduledFrom,
        DateTimeOffset scheduledUntil,
        CancellationToken ct = default)
    {
        var bookingsToday = await db.Bookings.AsNoTracking()
            .CountAsync(x => x.ScheduledStart >= scheduledFrom && x.ScheduledStart < scheduledUntil, ct);

        var statusGroups = await db.Bookings.AsNoTracking()
            .GroupBy(x => x.Status)
            .Select(x => new { Status = x.Key, Count = x.Count() })
            .ToListAsync(ct);

        return new AdminBookingSnapshot(
            bookingsToday,
            statusGroups.ToDictionary(x => ToApiStatus(x.Status), x => x.Count));
    }

    public IReadOnlyList<AdminStatusDescriptor> GetStatusDescriptors() => StatusDescriptors;

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

    private static string StatusLabel(BookingStatus status) => status switch
    {
        BookingStatus.Draft => "Bản nháp",
        BookingStatus.PendingPayment => "Chờ thanh toán",
        BookingStatus.PaymentReconciliationPending => "Đang đối soát",
        BookingStatus.NeedsManualReview => "Cần đối soát",
        BookingStatus.Confirmed => "Đã xác nhận",
        BookingStatus.MatchingFailed => "Ghép ca thất bại",
        BookingStatus.CaregiverAccepted => "Caregiver đã nhận",
        BookingStatus.CaregiverEnRoute => "Đang di chuyển",
        BookingStatus.InProgress => "Đang diễn ra",
        BookingStatus.CheckoutPendingReview => "Chờ duyệt checkout",
        BookingStatus.Completed => "Hoàn thành",
        BookingStatus.Cancelled => "Đã hủy",
        BookingStatus.Crisis => "Khẩn cấp",
        BookingStatus.Disputed => "Đang khiếu nại",
        BookingStatus.Refunded => "Đã hoàn tiền",
        _ => status.ToString()
    };

    private static string StatusTone(BookingStatus status) => status switch
    {
        BookingStatus.Completed or BookingStatus.Confirmed or BookingStatus.Refunded => "success",
        BookingStatus.InProgress or BookingStatus.CaregiverEnRoute or BookingStatus.CaregiverAccepted => "info",
        BookingStatus.PendingPayment or BookingStatus.PaymentReconciliationPending
            or BookingStatus.NeedsManualReview or BookingStatus.CheckoutPendingReview
            or BookingStatus.Disputed => "warning",
        BookingStatus.Cancelled or BookingStatus.MatchingFailed or BookingStatus.Crisis => "danger",
        _ => "neutral"
    };
}
