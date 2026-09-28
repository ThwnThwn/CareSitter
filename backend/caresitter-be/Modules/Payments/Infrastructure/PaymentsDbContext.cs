using CareSitter.Infrastructure.Persistence;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>DbContext module Payments — schema "payments" (wallet, payment_intents, ledger, payout).</summary>
public sealed class PaymentsDbContext : ModuleDbContext
{
    public const string SchemaName = "payments";

    public PaymentsDbContext(DbContextOptions<PaymentsDbContext> options, ICurrentUser? currentUser = null)
        : base(options, currentUser) { }

    protected override string Schema => SchemaName;

    public DbSet<WalletAccount> WalletAccounts => Set<WalletAccount>();
    public DbSet<PaymentIntent> PaymentIntents => Set<PaymentIntent>();
    public DbSet<PaymentWebhook> PaymentWebhooks => Set<PaymentWebhook>();
    public DbSet<LedgerEntry> LedgerEntries => Set<LedgerEntry>();
    public DbSet<PayoutRequest> PayoutRequests => Set<PayoutRequest>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<WalletAccount>(b =>
        {
            b.ToTable("wallet_accounts");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.UserId).HasColumnName("user_id");
            b.Property(x => x.AccountType).HasColumnName("account_type").HasMaxLength(20);
            b.Property(x => x.AvailableBalance).HasColumnName("available_balance");
            b.Property(x => x.PendingBalance).HasColumnName("pending_balance");
            b.Property(x => x.Currency).HasColumnName("currency").HasMaxLength(3).IsFixedLength();
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<PaymentIntent>(b =>
        {
            b.ToTable("payment_intents");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.CustomerId).HasColumnName("customer_id");
            b.Property(x => x.Provider).HasColumnName("provider").HasMaxLength(20);
            b.Property(x => x.Amount).HasColumnName("amount");
            b.Property(x => x.Currency).HasColumnName("currency").HasMaxLength(3).IsFixedLength();
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.ProviderTransactionId).HasColumnName("provider_transaction_id").HasMaxLength(255);
            b.Property(x => x.ProviderOrderRef).HasColumnName("provider_order_ref").HasMaxLength(100);
            b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key").HasMaxLength(255);
            b.Property(x => x.RequestPayload).HasColumnName("request_payload").HasColumnType("jsonb");
            b.Property(x => x.ResponsePayload).HasColumnName("response_payload").HasColumnType("jsonb");
            b.Property(x => x.ReconciliationAttempts).HasColumnName("reconciliation_attempts");
            b.Property(x => x.ReconciliationStartedAt).HasColumnName("reconciliation_started_at");
            b.Property(x => x.LastReconciliationAt).HasColumnName("last_reconciliation_at");
            b.Property(x => x.NextReconciliationAt).HasColumnName("next_reconciliation_at");
            b.Property(x => x.LastReconciliationError).HasColumnName("last_reconciliation_error");
            b.Property(x => x.FinalizedSource).HasColumnName("finalized_source");
            b.Property(x => x.ManualReviewReason).HasColumnName("manual_review_reason");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            b.HasIndex(x => x.IdempotencyKey).IsUnique();
            b.HasIndex(x => new { x.Provider, x.ProviderOrderRef }).IsUnique();
            b.HasIndex(x => new { x.BookingId, x.Provider })
                .IsUnique()
                .HasFilter("status = 'PENDING'")
                .HasDatabaseName("ux_payment_intent_one_pending_per_booking");
            b.Ignore(x => x.DomainEvents);
        });

        modelBuilder.Entity<PaymentWebhook>(b =>
        {
            b.ToTable("payment_webhooks");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.Provider).HasColumnName("provider").HasMaxLength(20);
            b.Property(x => x.ProviderEventId).HasColumnName("provider_event_id").HasMaxLength(255);
            b.Property(x => x.EventType).HasColumnName("event_type").HasMaxLength(100);
            b.Property(x => x.Payload).HasColumnName("payload").HasColumnType("jsonb");
            b.Property(x => x.ProcessedAt).HasColumnName("processed_at");
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Ignore(x => x.UpdatedAt); // payment_webhooks has no updated_at column
            b.HasIndex(x => new { x.Provider, x.ProviderEventId }).IsUnique();
        });

        modelBuilder.Entity<LedgerEntry>(b =>
        {
            b.ToTable("ledger_entries");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.BookingId).HasColumnName("booking_id");
            b.Property(x => x.PaymentIntentId).HasColumnName("payment_intent_id");
            b.Property(x => x.PayoutRequestId).HasColumnName("payout_request_id");
            b.Property(x => x.TransactionType).HasColumnName("transaction_type").HasMaxLength(30);
            b.Property(x => x.DebitAccount).HasColumnName("debit_account").HasMaxLength(100);
            b.Property(x => x.CreditAccount).HasColumnName("credit_account").HasMaxLength(100);
            b.Property(x => x.Amount).HasColumnName("amount");
            b.Property(x => x.Currency).HasColumnName("currency").HasMaxLength(3).IsFixedLength();
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.Metadata).HasColumnName("metadata").HasColumnType("jsonb");
            b.Property(x => x.CreatedAt).HasColumnName("created_at");
            b.Ignore(x => x.UpdatedAt); // ledger_entries has no updated_at column
            b.HasIndex(x => new { x.BookingId, x.TransactionType })
                .IsUnique()
                .HasFilter("booking_id IS NOT NULL AND transaction_type IN ('ESCROW_LOCK', 'PLATFORM_FEE', 'CAREGIVER_EARNING', 'REFUND')")
                .HasDatabaseName("ux_ledger_booking_transaction_type");
        });

        modelBuilder.Entity<PayoutRequest>(b =>
        {
            b.ToTable("payout_requests");
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).HasColumnName("id");
            b.Property(x => x.CaregiverId).HasColumnName("caregiver_id");
            b.Property(x => x.WalletAccountId).HasColumnName("wallet_account_id");
            b.Property(x => x.IdempotencyKey).HasColumnName("idempotency_key").HasMaxLength(100);
            b.Property(x => x.Amount).HasColumnName("amount");
            b.Property(x => x.BankName).HasColumnName("bank_name").HasMaxLength(255);
            b.Property(x => x.AccountHolderName).HasColumnName("account_holder_name").HasMaxLength(255);
            b.Property(x => x.AccountNumberEncrypted).HasColumnName("account_number_encrypted");
            b.Property(x => x.Status).HasColumnName("status").HasMaxLength(20);
            b.Property(x => x.RequestedAt).HasColumnName("requested_at");
            b.Property(x => x.ReviewedByAdminId).HasColumnName("reviewed_by_admin_id");
            b.Property(x => x.ReviewedAt).HasColumnName("reviewed_at");
            b.Property(x => x.RejectReason).HasColumnName("reject_reason");
            b.HasIndex(x => new { x.CaregiverId, x.IdempotencyKey })
                .IsUnique()
                .HasDatabaseName("uq_payout_caregiver_idempotency");
            b.Ignore(x => x.CreatedAt); // payout_requests has no created_at column (requested_at is the domain field)
            b.Ignore(x => x.UpdatedAt); // payout_requests has no updated_at column
        });
    }
}
