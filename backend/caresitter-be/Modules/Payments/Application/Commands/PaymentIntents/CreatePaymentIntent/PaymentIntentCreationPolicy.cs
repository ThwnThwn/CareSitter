using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Payments.Application.PaymentIntents;

internal enum PaymentRetryAction { Finalize, Block, CloseExpired, CloseFailed }
internal sealed record PaymentRetryDecision(PaymentRetryAction Action, PaymentIntentConflict? Conflict = null);

/// <summary>Pure admission/retry decisions. Provider calls, finalization and locking remain adapters.</summary>
internal static class PaymentIntentCreationPolicy
{
    internal static PaymentIntentConflict? CheckBooking(BookingPaymentSnapshot booking, DateTimeOffset now)
    {
        if (booking.State != BookingPaymentState.PendingPayment)
            return new("Booking khong o trạng thái cho thanh toan.");
        return booking.PaymentDeadline <= now
            ? new("Booking da het thoi han thanh toan va dang cho doi soat.",
                "BOOKING_PAYMENT_DEADLINE_EXPIRED", PaymentDeadline: booking.PaymentDeadline)
            : null;
    }

    internal static PaymentIntentConflict? CheckPreviousAttempt(string? status) => status == "SUCCEEDED"
        ? new("Booking da thanh toan thành công.", "PAYMENT_ALREADY_SUCCEEDED") : null;

    internal static PaymentRetryDecision EvaluateRetry(VNPayQueryState state,
        DateTimeOffset createdAt, TimeSpan paymentTimeout) => state switch
    {
        VNPayQueryState.Succeeded => new(PaymentRetryAction.Finalize),
        VNPayQueryState.Processing => new(PaymentRetryAction.Block,
            new("Giao dịch trước vẫn đang được VNPay xử lý.", "PAYMENT_IN_PROGRESS",
                ExpiresAt: createdAt.Add(paymentTimeout))),
        VNPayQueryState.Unknown => new(PaymentRetryAction.Block,
            new("VNPay chưa trả về trạng thái chắc chắn cho giao dịch trước.", "PAYMENT_STATUS_UNKNOWN",
                ExpiresAt: createdAt.Add(paymentTimeout))),
        VNPayQueryState.NotFound => new(PaymentRetryAction.CloseExpired),
        VNPayQueryState.Failed => new(PaymentRetryAction.CloseFailed),
        _ => new(PaymentRetryAction.Block, QueryUnavailable())
    };

    internal static PaymentIntentConflict QueryUnavailable() => new(
        "Chua the xac minh trạng thái giao dịch truoc. Vui long thu lai sau.", "PAYMENT_STATUS_UNKNOWN");

    internal static PaymentIntentConflict FinalizationConflict(bool succeeded) => succeeded
        ? new("giao dịch truoc da thanh toan thành công.", "PAYMENT_ALREADY_SUCCEEDED")
        : new("giao dịch da thành công nhung booking chua the chot tu dong.", "PAYMENT_NEEDS_REVIEW");
}
