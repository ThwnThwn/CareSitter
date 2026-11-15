using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingPaymentSummaryPolicy
{
    internal static BookingPaymentSummaryResponse Describe(Domain.Booking booking, DateTimeOffset now)
    {
        var pending = booking.Status == BookingStatus.PendingPayment;
        var uncertain = booking.Status is BookingStatus.PaymentReconciliationPending or BookingStatus.NeedsManualReview;
        var cancellation = BookingCancellationPolicy.Evaluate(booking, now);
        var canCancel = cancellation.IsSuccess &&
            BookingStateMachine.CanTransition(booking.Status, BookingStatus.Cancelled);
        var requiresDispute = cancellation.IsFailure;
        var refund = canCancel && !uncertain ? cancellation.Value.RefundAmount : (long?)null;
        var projected = BookingCancellationPolicy.PreviewAfterPayment(booking, now);
        var projectedRefund = pending && now < booking.PaymentDeadline && now < booking.ScheduledStart && projected.IsSuccess
            ? projected.Value.RefundAmount : (long?)null;
        var cancellationExplanation = uncertain
            ? "Bạn có thể yêu cầu hủy lịch. Khoản thanh toán (nếu có) cần được đối soát trước khi xác định hoàn tiền. Không thanh toán lại trong lúc đối soát."
            : requiresDispute
                ? "Ca đã bắt đầu hoặc cần xác minh việc thực hiện. Hãy gửi yêu cầu hỗ trợ để xác định khoản hoàn tiền."
                : canCancel
                    ? refund > 0
                        ? "Nếu hủy lúc này, số tiền bạn đã thanh toán cho lịch được hoàn về phương thức thanh toán ban đầu sau khi xử lý. Thời gian nhận tiền phụ thuộc đơn vị thanh toán."
                        : "Lịch chưa ghi nhận thanh toán thành công nên hiện không có khoản tiền cần hoàn."
                    : "Lịch hiện không thể hủy. Liên hệ hỗ trợ nếu bạn cần kiểm tra thanh toán hoặc khoản hoàn tiền.";
        return new(booking.Id, "VND", pending ? booking.CustomerPayableAmount : 0,
            booking.EscrowAmount, booking.PromotionDiscountAmount, booking.PaymentDeadline,
            pending && now < booking.PaymentDeadline && now < booking.ScheduledStart,
            booking.DisputeWindowHours,
            booking.Status == BookingStatus.Completed && booking.ActualEnd is { } ended
                ? ended.AddHours(booking.DisputeWindowHours) : null,
            canCancel, refund, requiresDispute,
            pending ? "Thanh toán để gửi yêu cầu nhận ca. Lịch chỉ có người chăm sóc khi họ xác nhận nhận ca."
                : uncertain ? "Chưa xác định xong kết quả thanh toán. Không thanh toán lại trong lúc đối soát."
                : "Không có khoản thanh toán mới cần thực hiện cho lịch ở trạng thái hiện tại.",
            $"Tiền được giữ trong hệ thống. Sau khi ca được xác nhận hoàn tất và hết thời hạn phản ánh {booking.DisputeWindowHours} giờ tính từ thời điểm kết thúc thực tế, khoản thu nhập mới đủ điều kiện chuyển vào ví người chăm sóc nếu không có tranh chấp. Rút về ngân hàng là bước riêng.",
            "Nếu hệ thống kết thúc tìm kiếm mà không có người chăm sóc nhận ca, khoản đã thanh toán được xử lý hoàn về phương thức ban đầu. Bạn cũng có thể hủy theo điều kiện hiện tại; tiền hoàn chỉ được xác nhận sau khi đơn vị thanh toán xử lý.",
            cancellationExplanation, now, projectedRefund,
            projectedRefund.HasValue
                ? "Theo điều kiện hiện tại, nếu thanh toán thành công rồi hủy trước giờ bắt đầu, số tiền dự kiến được hoàn như trên. Điều kiện được kiểm tra lại lúc hủy; thời gian nhận tiền phụ thuộc đơn vị thanh toán."
                : "Chưa thể dự tính khoản hoàn sau thanh toán. Vui lòng kiểm tra lại điều kiện của lịch hoặc liên hệ hỗ trợ.");
    }
}
