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
            return Error.Validation("wallet.account_type", "account_type khong duoc rong.");
        if (string.IsNullOrWhiteSpace(currency))
            return Error.Validation("wallet.currency", "currency khong duoc rong.");

        return new WalletAccount(Guid.NewGuid(), userId, accountType, currency);
    }
}
