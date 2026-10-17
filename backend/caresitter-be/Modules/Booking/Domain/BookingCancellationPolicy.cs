using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Domain;

public sealed record BookingCancellationDecision(long RefundAmount);

/// <summary>
/// Chính sách hủy phía khách hàng. Sau giờ bắt đầu, ca có caregiver phải đi
/// qua dispute để xác định no-show hoặc phần dịch vụ đã thực hiện.
/// </summary>
public static class BookingCancellationPolicy
{
    public static Result<BookingCancellationDecision> Evaluate(
        Booking booking,
        DateTimeOffset cancelledAt)
    {
        if (booking.Status is BookingStatus.InProgress or
            BookingStatus.CheckoutPendingReview or BookingStatus.Completed or
            BookingStatus.Crisis or BookingStatus.Disputed)
            return RequiresDispute();

        var noServiceCanBeDelivered = booking.Status == BookingStatus.MatchingFailed ||
            (booking.Status == BookingStatus.Confirmed && booking.CaregiverId is null);
        var beforeStart = cancelledAt < booking.ScheduledStart;
        var paidBooking = booking.Status is BookingStatus.Confirmed or
            BookingStatus.MatchingFailed or BookingStatus.CaregiverAccepted or
            BookingStatus.CaregiverEnRoute;

        if (paidBooking && (beforeStart || noServiceCanBeDelivered))
            return new BookingCancellationDecision(booking.CustomerPayableAmount);

        if (paidBooking)
            return RequiresDispute();

        return new BookingCancellationDecision(0);
    }

    private static Error RequiresDispute() => Error.Conflict(
        "booking.cancel.requires_dispute",
        "Ca đã bắt đầu hoặc có dấu hiệu no-show. Vui lòng mở khiếu nại để xác định phần hoàn tiền.");
}
