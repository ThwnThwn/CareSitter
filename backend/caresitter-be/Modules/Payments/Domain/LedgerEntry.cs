using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

/// <summary>
/// But toan so cai (double-entry). Bat bien khi POSTED (khong sua/xoa — tao entry REVERSE).
/// Map sang bang ledger_entries. Bang KHONG co updated_at.
/// </summary>
public sealed class LedgerEntry : Entity
{
    private LedgerEntry() { } // EF

    private LedgerEntry(
        Guid id,
        Guid? bookingId,
        Guid? paymentIntentId,
        string transactionType,
        string debitAccount,
        string creditAccount,
        long amount,
        string currency,
        string? metadata)
    {
        Id = id;
        BookingId = bookingId;
        PaymentIntentId = paymentIntentId;
        TransactionType = transactionType;
        DebitAccount = debitAccount;
        CreditAccount = creditAccount;
        Amount = amount;
        Currency = currency;
        Metadata = metadata;
        Status = "PENDING";
    }

    public Guid? BookingId { get; private set; }
    public Guid? PaymentIntentId { get; private set; }

    /// <summary>Allowed values: 'ESCROW_LOCK', 'PLATFORM_FEE', 'CAREGIVER_EARNING', 'REFUND', 'PAYOUT', 'PENALTY', 'BONUS'.</summary>
    public string TransactionType { get; private set; } = null!;

    public string DebitAccount { get; private set; } = null!;
    public string CreditAccount { get; private set; } = null!;
    public long Amount { get; private set; }
    public string Currency { get; private set; } = null!;

    /// <summary>Allowed values: 'PENDING', 'POSTED', 'REVERSED'.</summary>
    public string Status { get; private set; } = null!;

    public string? Metadata { get; private set; }

    public static Result<LedgerEntry> Create(
        string transactionType,
        string debitAccount,
        string creditAccount,
        long amount,
        Guid? bookingId = null,
        Guid? paymentIntentId = null,
        string currency = "VND",
        string? metadata = null)
    {
        if (string.IsNullOrWhiteSpace(transactionType))
            return Error.Validation("ledger.transaction_type", "transaction_type không được rỗng.");
        if (string.IsNullOrWhiteSpace(debitAccount))
            return Error.Validation("ledger.debit_account", "debit_account không được rỗng.");
        if (string.IsNullOrWhiteSpace(creditAccount))
            return Error.Validation("ledger.credit_account", "credit_account không được rỗng.");
        if (amount < 0)
            return Error.Validation("ledger.amount", "amount không được âm.");

        return new LedgerEntry(Guid.NewGuid(), bookingId, paymentIntentId, transactionType,
            debitAccount, creditAccount, amount, currency, metadata);
    }
}
