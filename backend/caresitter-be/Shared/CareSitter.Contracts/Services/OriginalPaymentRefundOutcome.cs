namespace CareSitter.Contracts.Services;

public enum OriginalPaymentRefundState
{
    NotRequired,
    Pending,
    ManualActionRequired,
    Confirmed,
    Failed
}

/// <summary>
/// Trạng thái refund về đúng phương thức đã thu tiền. Chỉ Confirmed có nghĩa
/// provider đã xác nhận và Payments đã ghi ledger.
/// </summary>
public sealed record OriginalPaymentRefundOutcome(
    OriginalPaymentRefundState State,
    Guid? RefundRequestId = null,
    string? Provider = null,
    long Amount = 0,
    string? ErrorCode = null);
