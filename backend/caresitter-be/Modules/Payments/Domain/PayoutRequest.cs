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
        long amount,
        string bankName,
        string accountHolderName,
        string accountNumberEncrypted)
    {
        Id = id;
        CaregiverId = caregiverId;
        WalletAccountId = walletAccountId;
        Amount = amount;
        BankName = bankName;
        AccountHolderName = accountHolderName;
        AccountNumberEncrypted = accountNumberEncrypted;
        Status = "PENDING";
        RequestedAt = DateTimeOffset.UtcNow;
    }

    public Guid CaregiverId { get; private set; }
    public Guid WalletAccountId { get; private set; }
    public long Amount { get; private set; }

    public string BankName { get; private set; } = null!;
    public string AccountHolderName { get; private set; } = null!;
    public string AccountNumberEncrypted { get; private set; } = null!;

    /// <summary>Allowed values: 'PENDING', 'APPROVED', 'REJECTED', 'PROCESSING', 'PAID', 'FAILED'.</summary>
    public string Status { get; private set; } = null!;

    public DateTimeOffset RequestedAt { get; private set; }
    public Guid? ReviewedByAdminId { get; private set; }
    public DateTimeOffset? ReviewedAt { get; private set; }
    public string? RejectReason { get; private set; }

    public static Result<PayoutRequest> Create(
        Guid caregiverId,
        Guid walletAccountId,
        long amount,
        string bankName,
        string accountHolderName,
        string accountNumberEncrypted)
    {
        if (amount < 0)
            return Error.Validation("payout.amount", "amount không được âm.");
        if (string.IsNullOrWhiteSpace(bankName))
            return Error.Validation("payout.bank_name", "bank_name không được rỗng.");
        if (string.IsNullOrWhiteSpace(accountHolderName))
            return Error.Validation("payout.account_holder_name", "account_holder_name không được rỗng.");
        if (string.IsNullOrWhiteSpace(accountNumberEncrypted))
            return Error.Validation("payout.account_number", "account_number_encrypted không được rỗng.");

        return new PayoutRequest(Guid.NewGuid(), caregiverId, walletAccountId, amount,
            bankName, accountHolderName, accountNumberEncrypted);
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

    public Result MarkProcessing()
    {
        if (Status != "APPROVED")
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> PROCESSING.");
        Status = "PROCESSING";
        return Result.Success();
    }

    public Result MarkPaid()
    {
        if (Status is not ("APPROVED" or "PROCESSING"))
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> PAID.");
        Status = "PAID";
        return Result.Success();
    }

    public Result MarkFailed()
    {
        if (Status is not ("APPROVED" or "PROCESSING"))
            return Error.Conflict("payout.status", $"không thể chuyen {Status} -> FAILED.");
        Status = "FAILED";
        return Result.Success();
    }
}
