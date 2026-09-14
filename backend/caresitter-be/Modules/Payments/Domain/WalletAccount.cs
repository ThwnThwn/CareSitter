using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

/// <summary>
/// Aggregate root cho vi tien (wallet). Cache balance suy ra tu ledger. Map sang bang wallet_accounts.
/// </summary>
public sealed class WalletAccount : AggregateRoot
{
    private WalletAccount() { } // EF

    private WalletAccount(
        Guid id,
        Guid? userId,
        string accountType,
        string currency) : base(id)
    {
        UserId = userId;
        AccountType = accountType;
        Currency = currency;
        AvailableBalance = 0;
        PendingBalance = 0;
    }

    public Guid? UserId { get; private set; }

    /// <summary>Allowed values: 'CAREGIVER', 'PLATFORM'.</summary>
    public string AccountType { get; private set; } = null!;

    public long AvailableBalance { get; private set; }
    public long PendingBalance { get; private set; }
    public string Currency { get; private set; } = null!;

    public static Result<WalletAccount> Create(
        Guid? userId,
        string accountType,
        string currency = "VND")
    {
        if (string.IsNullOrWhiteSpace(accountType))
            return Error.Validation("wallet.account_type", "account_type không được rỗng.");
        if (string.IsNullOrWhiteSpace(currency))
            return Error.Validation("wallet.currency", "currency không được rỗng.");

        return new WalletAccount(Guid.NewGuid(), userId, accountType, currency);
    }

    public Result DeductAvailable(long amount)
    {
        if (amount <= 0)
            return Error.Validation("wallet.amount", "amount phai lon hon 0.");
        if (AvailableBalance < amount)
            return Error.Validation("wallet.balance", "So du kha dung khong du.");
        AvailableBalance -= amount;
        return Result.Success();
    }

    public Result AddAvailable(long amount)
    {
        if (amount <= 0)
            return Error.Validation("wallet.amount", "amount phai lon hon 0.");
        AvailableBalance += amount;
        return Result.Success();
    }

    public Result AddPending(long amount)
    {
        if (amount <= 0)
            return Error.Validation("wallet.amount", "amount phai lon hon 0.");
        PendingBalance += amount;
        return Result.Success();
    }

    public Result ReleasePending(long amount)
    {
        if (amount <= 0)
            return Error.Validation("wallet.amount", "amount phai lon hon 0.");
        if (PendingBalance < amount)
            return Error.Validation("wallet.pending_balance", "So du tam giu khong du.");
        PendingBalance -= amount;
        AvailableBalance += amount;
        return Result.Success();
    }

    public Result FreezePending(long amount)
    {
        if (amount <= 0)
            return Error.Validation("wallet.amount", "amount phai lon hon 0.");
        if (PendingBalance < amount)
            return Error.Validation("wallet.pending_balance", "So du tam giu khong du de dong bang.");
        PendingBalance -= amount;
        return Result.Success();
    }
}
