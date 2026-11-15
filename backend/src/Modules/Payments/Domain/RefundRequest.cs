using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

public sealed class RefundRequest : Entity
{
    private RefundRequest() { }

    private RefundRequest(
        Guid id,
        PaymentIntent paymentIntent,
        long amount,
        string reason,
        string requestId,
        DateTimeOffset requestedAt,
        bool canProcessAutomatically)
    {
        Id = id;
        BookingId = paymentIntent.BookingId;
        PaymentIntentId = paymentIntent.Id;
        CustomerId = paymentIntent.CustomerId;
        Provider = paymentIntent.Provider;
        Amount = amount;
        Currency = paymentIntent.Currency;
        Reason = reason;
        RequestId = requestId;
        OriginalProviderOrderRef = paymentIntent.ProviderOrderRef;
        OriginalProviderTransactionId = paymentIntent.ProviderTransactionId;
        OriginalProviderCreateDate = paymentIntent.ProviderCreateDate;
        Status = canProcessAutomatically ? "PENDING" : "MANUAL_REQUIRED";
        RequestedAt = requestedAt;
    }

    public Guid BookingId { get; private set; }
    public Guid PaymentIntentId { get; private set; }
    public Guid CustomerId { get; private set; }
    public string Provider { get; private set; } = null!;
    public long Amount { get; private set; }
    public string Currency { get; private set; } = null!;
    public string Reason { get; private set; } = null!;
    public string RequestId { get; private set; } = null!;
    public string? OriginalProviderOrderRef { get; private set; }
    public string? OriginalProviderTransactionId { get; private set; }
    public string? OriginalProviderCreateDate { get; private set; }

    /// <summary>PENDING, PROCESSING, UNKNOWN, MANUAL_REQUIRED, SUCCEEDED hoặc FAILED.</summary>
    public string Status { get; private set; } = null!;
    public string? ProviderResponseId { get; private set; }
    public string? ProviderRefundId { get; private set; }
    public string? ProviderTransactionStatus { get; private set; }
    public string? LastErrorCode { get; private set; }
    public int AttemptCount { get; private set; }
    public DateTimeOffset RequestedAt { get; private set; }
    public DateTimeOffset? SubmissionStartedAt { get; private set; }
    public DateTimeOffset? LastAttemptAt { get; private set; }
    public DateTimeOffset? NextAttemptAt { get; private set; }
    public Guid? LeaseId { get; private set; }
    public DateTimeOffset? LeaseUntil { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }
    public Guid? ConfirmedByAdminId { get; private set; }
    public string? AdminConfirmationNote { get; private set; }

    public static Result<RefundRequest> Create(
        PaymentIntent paymentIntent,
        string reason,
        DateTimeOffset requestedAt,
        bool canProcessAutomatically) =>
        Create(paymentIntent, paymentIntent.Amount, reason, requestedAt,
            canProcessAutomatically);

    public static Result<RefundRequest> Create(
        PaymentIntent paymentIntent,
        long amount,
        string reason,
        DateTimeOffset requestedAt,
        bool canProcessAutomatically)
    {
        if (paymentIntent.Status != "SUCCEEDED" || paymentIntent.Amount <= 0)
            return Error.Validation("refund.payment", "Chỉ hoàn payment intent đã thu tiền thành công.");
        if (amount <= 0 || amount > paymentIntent.Amount)
            return Error.Validation("refund.amount",
                "Số tiền hoàn phải lớn hơn 0 và không vượt số tiền thực thu.");
        if (paymentIntent.Currency != "VND")
            return Error.Validation("refund.currency", "Refund hiện chỉ hỗ trợ VND.");
        if (string.IsNullOrWhiteSpace(reason))
            return Error.Validation("refund.reason", "Lý do hoàn tiền là bắt buộc.");

        var requestId = $"RF{Guid.NewGuid():N}"[..32];
        return new RefundRequest(Guid.NewGuid(), paymentIntent, amount, reason.Trim(), requestId,
            requestedAt, canProcessAutomatically);
    }

    public Result BeginProviderAttempt(
        Guid leaseId,
        DateTimeOffset now,
        DateTimeOffset leaseUntil,
        DateTimeOffset nextAttemptAt)
    {
        if (Status is not ("PENDING" or "PROCESSING" or "UNKNOWN"))
            return Error.Conflict("refund.status", $"Refund đang ở trạng thái {Status}.");
        if (LeaseUntil is { } currentLease && currentLease > now)
            return Error.Conflict("refund.lease", "Refund đang được worker khác xử lý.");

        Status = "PROCESSING";
        SubmissionStartedAt ??= now;
        LastAttemptAt = now;
        NextAttemptAt = nextAttemptAt;
        LeaseId = leaseId;
        LeaseUntil = leaseUntil;
        AttemptCount++;
        return Result.Success();
    }

    public Result RecordProviderProgress(
        Guid leaseId,
        string status,
        string? providerResponseId,
        string? providerRefundId,
        string? providerTransactionStatus,
        string? errorCode,
        DateTimeOffset? nextAttemptAt,
        DateTimeOffset completedAt)
    {
        if (Status == "SUCCEEDED") return Result.Success();
        if (Status != "PROCESSING" || LeaseId != leaseId)
            return Error.Conflict("refund.lease", "Kết quả refund không thuộc lease hiện hành.");
        if (status is not ("PROCESSING" or "UNKNOWN" or "SUCCEEDED" or "FAILED"))
            return Error.Validation("refund.status", "Trạng thái provider không hợp lệ.");

        Status = status;
        ProviderResponseId = providerResponseId ?? ProviderResponseId;
        ProviderRefundId = providerRefundId ?? ProviderRefundId;
        ProviderTransactionStatus = providerTransactionStatus ?? ProviderTransactionStatus;
        LastErrorCode = errorCode;
        NextAttemptAt = nextAttemptAt;
        LeaseId = null;
        LeaseUntil = null;
        if (status is "SUCCEEDED" or "FAILED")
            CompletedAt = completedAt;
        return Result.Success();
    }

    public Result ConfirmManual(
        Guid adminId,
        string providerRefundId,
        string confirmationNote,
        DateTimeOffset confirmedAt)
    {
        if (Status == "SUCCEEDED") return Result.Success();
        if (Status != "MANUAL_REQUIRED")
            return Error.Conflict("refund.status", "Chỉ refund chờ xử lý thủ công mới được xác nhận.");
        if (string.IsNullOrWhiteSpace(providerRefundId))
            return Error.Validation("refund.provider_refund_id", "Mã xác nhận hoàn tiền của provider là bắt buộc.");
        if (string.IsNullOrWhiteSpace(confirmationNote))
            return Error.Validation("refund.confirmation_note", "Ghi chú bằng chứng đối soát là bắt buộc.");

        Status = "SUCCEEDED";
        ProviderRefundId = providerRefundId.Trim();
        ProviderTransactionStatus = "CONFIRMED_MANUALLY";
        ConfirmedByAdminId = adminId;
        AdminConfirmationNote = confirmationNote.Trim();
        CompletedAt = confirmedAt;
        NextAttemptAt = null;
        return Result.Success();
    }
}
