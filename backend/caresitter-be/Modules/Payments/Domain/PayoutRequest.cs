using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

/// <summary>
/// Yeu cau rut tien cua CSV (snapshot thong tin bank). Map sang bang payout_requests.
/// Bang KHONG co created_at/updated_at — requested_at la field domain rieng.
/// </summary>
public sealed class PayoutRequest : Entity
{
    private PayoutRequest() { } // EF

    private PayoutRequest(
        Guid id,
        Guid caregiverId,
        Guid walletAccountId,
        string idempotencyKey,
        long amount,
        string bankName,
        string bankBin,
        string accountHolderName,
        string accountNumberEncrypted)
    {
        Id = id;
        CaregiverId = caregiverId;
        WalletAccountId = walletAccountId;
        IdempotencyKey = idempotencyKey;
        Amount = amount;
        BankName = bankName;
        BankBin = bankBin;
        AccountHolderName = accountHolderName;
        AccountNumberEncrypted = accountNumberEncrypted;
        Provider = "PAYOS";
        ProviderReferenceId = $"CS{id:N}";
        Status = "PENDING";
        RequestedAt = DateTimeOffset.UtcNow;
    }

    public Guid CaregiverId { get; private set; }
    public Guid WalletAccountId { get; private set; }
    public string IdempotencyKey { get; private set; } = null!;
    public long Amount { get; private set; }

    public string BankName { get; private set; } = null!;
    public string BankBin { get; private set; } = null!;
    public string AccountHolderName { get; private set; } = null!;
    public string AccountNumberEncrypted { get; private set; } = null!;

    public string Provider { get; private set; } = null!;
    public string ProviderReferenceId { get; private set; } = null!;
    public string? ProviderPayoutId { get; private set; }
    public string? ProviderState { get; private set; }
    public string? ProviderTransactionId { get; private set; }
    public string? ProviderErrorCode { get; private set; }
    public int ProviderAttemptCount { get; private set; }
    public DateTimeOffset? ProcessingStartedAt { get; private set; }
    public DateTimeOffset? LastProviderCheckAt { get; private set; }
    public DateTimeOffset? NextProviderCheckAt { get; private set; }
    public DateTimeOffset? CompletedAt { get; private set; }

    /// <summary>Allowed values: 'PENDING', 'APPROVED', 'REJECTED', 'PROCESSING', 'PAID', 'FAILED'.</summary>
    public string Status { get; private set; } = null!;

    public DateTimeOffset RequestedAt { get; private set; }
    public Guid? ReviewedByAdminId { get; private set; }
    public DateTimeOffset? ReviewedAt { get; private set; }
    public string? RejectReason { get; private set; }

    public static Result<PayoutRequest> Create(
        Guid caregiverId,
        Guid walletAccountId,
        string idempotencyKey,
        long amount,
        string bankName,
        string bankBin,
        string accountHolderName,
        string accountNumberEncrypted)
    {
        if (string.IsNullOrWhiteSpace(idempotencyKey) || idempotencyKey.Trim().Length > 100)
            return Error.Validation("payout.idempotency_key", "idempotency_key không hợp lệ.");
        if (amount < 100_000)
            return Error.Validation("payout.amount", "Số tiền rút tối thiểu là 100.000đ.");
        if (string.IsNullOrWhiteSpace(bankName))
            return Error.Validation("payout.bank_name", "bank_name không được rỗng.");
        if (bankBin is null || bankBin.Length != 6 || !bankBin.All(char.IsAsciiDigit))
            return Error.Validation("payout.bank_bin", "bank_bin phải gồm đúng 6 chữ số.");
        if (string.IsNullOrWhiteSpace(accountHolderName))
            return Error.Validation("payout.account_holder_name", "account_holder_name không được rỗng.");
        if (string.IsNullOrWhiteSpace(accountNumberEncrypted))
            return Error.Validation("payout.account_number", "account_number_encrypted không được rỗng.");

        var id = Guid.NewGuid();
        return new PayoutRequest(id, caregiverId, walletAccountId, idempotencyKey.Trim(), amount,
            bankName.Trim(), bankBin, accountHolderName.Trim(), accountNumberEncrypted);
    }

    public Result Approve(Guid adminId)
    {
        if (Status != "PENDING")
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> APPROVED.");
        Status = "APPROVED";
        ReviewedByAdminId = adminId;
        ReviewedAt = DateTimeOffset.UtcNow;
        return Result.Success();
    }

    public Result Reject(Guid adminId, string? reason = null)
    {
        if (Status != "PENDING")
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> REJECTED.");
        Status = "REJECTED";
        ReviewedByAdminId = adminId;
        ReviewedAt = DateTimeOffset.UtcNow;
        RejectReason = reason;
        return Result.Success();
    }

    public Result BeginProviderAttempt(DateTimeOffset now, DateTimeOffset nextCheckAt)
    {
        if (Status is not ("APPROVED" or "PROCESSING"))
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> PROCESSING.");
        Status = "PROCESSING";
        ProcessingStartedAt ??= now;
        LastProviderCheckAt = now;
        NextProviderCheckAt = nextCheckAt;
        ProviderAttemptCount++;
        return Result.Success();
    }

    public Result RecordProviderProgress(
        string? providerPayoutId,
        string providerState,
        string? providerTransactionId,
        string? errorCode,
        DateTimeOffset checkedAt,
        DateTimeOffset? nextCheckAt)
    {
        if (Status != "PROCESSING")
            return Error.Conflict("payout.status", $"không thể cập nhật provider khi payout đang {Status}.");
        if (!string.IsNullOrWhiteSpace(providerPayoutId))
        {
            if (ProviderPayoutId is not null && ProviderPayoutId != providerPayoutId)
                return Error.Conflict("payout.provider_id", "Provider payout id không khớp.");
            ProviderPayoutId = providerPayoutId;
        }
        ProviderState = providerState;
        ProviderTransactionId = providerTransactionId ?? ProviderTransactionId;
        ProviderErrorCode = errorCode;
        LastProviderCheckAt = checkedAt;
        NextProviderCheckAt = nextCheckAt;
        return Result.Success();
    }

    public Result MarkPaid(DateTimeOffset completedAt)
    {
        if (Status != "PROCESSING")
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> PAID.");
        Status = "PAID";
        CompletedAt = completedAt;
        NextProviderCheckAt = null;
        return Result.Success();
    }

    public Result MarkFailed(DateTimeOffset completedAt)
    {
        if (Status != "PROCESSING")
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> FAILED.");
        Status = "FAILED";
        CompletedAt = completedAt;
        NextProviderCheckAt = null;
        return Result.Success();
    }
}
