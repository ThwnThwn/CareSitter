using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Infrastructure;

/// <summary>
/// Implement IWalletService (Contracts). Booking goi qua interface, khong cham DbContext Payments.
/// MVP: ghi ledger that vao DB thay vi skeleton.
/// </summary>
internal sealed class WalletService(
    PaymentsDbContext db,
    IDisputeLookupService disputeLookup,
    IPeopleLookupService peopleLookup) : IWalletService
{
    public async Task<Result> LockEscrowAsync(Guid bookingId, long amount, string idempotencyKey, CancellationToken ct = default)
    {
        // Idempotent: check neu da ghi entry voi cung booking + type
        bool exists = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
        if (exists) return Result.Success(); // da lock roi

        var entry = LedgerEntry.Create("ESCROW_LOCK",
            "customer:escrow", "escrow:platform", amount, bookingId);
        if (entry.IsFailure) return entry.Error;
        db.LedgerEntries.Add(entry.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Hai IPN đồng thời có thể cùng qua bước AnyAsync; unique index là chốt race cuối.
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
            if (!committedByOtherRequest) throw;
        }
        return Result.Success();
    }

    public async Task<Result> RecordPromotionSubsidyAsync(Guid bookingId, long amount,
        CancellationToken ct = default)
    {
        if (amount == 0) return Result.Success();
        if (amount < 0)
            return Error.Validation("payments.promotion_subsidy",
                "Số tiền tài trợ promotion không được âm.");

        var exists = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "PROMOTION_SUBSIDY", ct);
        if (exists) return Result.Success();

        var entry = LedgerEntry.Create("PROMOTION_SUBSIDY",
            "revenue:platform", "escrow:platform", amount, bookingId,
            metadata: "{\"funding\":\"platform\"}");
        if (entry.IsFailure) return entry.Error;
        entry.Value.MarkPosted();
        db.LedgerEntries.Add(entry.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            if (!await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                    x.BookingId == bookingId &&
                    x.TransactionType == "PROMOTION_SUBSIDY", ct))
                throw;
        }
        return Result.Success();
    }

    public async Task<Result> SettleAsync(Guid bookingId, Guid caregiverId, long escrowAmount, long platformFeeAmount,
        CancellationToken ct = default)
    {
        if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
            return Error.Conflict("payments.dispute_open", "Booking dang co dispute mo, không thể giai ngan escrow.");

        var caregiverUserId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return Error.NotFound("payments.caregiver_not_found", "Không tìm thấy tài khoản của caregiver.");

        var caregiverAmount = escrowAmount - platformFeeAmount;
        if (caregiverAmount <= 0)
            return Error.Validation("payments.invalid_settlement_amount", "Số tiền caregiver nhận phải lớn hơn 0.");

        if (db.Database.IsRelational())
            return await SettleRelationalAsync(
                bookingId, caregiverUserId.Value, caregiverAmount, platformFeeAmount, ct);

        // In-memory path keeps domain unit tests lightweight. PostgreSQL uses the
        // locked/atomic path below and is covered by database race tests.
        bool settled = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
        if (settled) return Result.Success();

        var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
            "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
        if (feeEntry.IsFailure) return feeEntry.Error;
        feeEntry.Value.MarkPosted();

        var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
            "escrow:platform", $"wallet:caregiver:{caregiverUserId.Value}", caregiverAmount, bookingId);
        if (earningEntry.IsFailure) return earningEntry.Error;
        earningEntry.Value.MarkPosted();

        var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
            x.UserId == caregiverUserId.Value && x.AccountType == "CAREGIVER", ct);
        if (wallet is null)
        {
            var walletResult = WalletAccount.Create(caregiverUserId.Value, "CAREGIVER");
            if (walletResult.IsFailure) return walletResult.Error;
            wallet = walletResult.Value;
            db.WalletAccounts.Add(wallet);
        }

        var creditResult = wallet.AddAvailable(caregiverAmount);
        if (creditResult.IsFailure) return creditResult.Error;

        db.LedgerEntries.Add(feeEntry.Value);
        db.LedgerEntries.Add(earningEntry.Value);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // Request complete lặp lại chỉ cần xác nhận settlement đã được ghi bởi request thắng race.
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (!committedByOtherRequest) throw;
        }
        return Result.Success();
    }

    private async Task<Result> SettleRelationalAsync(
        Guid bookingId,
        Guid caregiverUserId,
        long caregiverAmount,
        long platformFeeAmount,
        CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Payments owns its concurrency boundary. An advisory transaction lock
            // serializes ledger mutations without locking a Booking-owned row.
            await AcquirePaymentLockAsync(bookingId, ct);

            var settled = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (settled)
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            await db.Database.ExecuteSqlInterpolatedAsync($$"""
                INSERT INTO payments.wallet_accounts (
                    id, user_id, account_type, available_balance, pending_balance,
                    currency, created_at, updated_at)
                VALUES (
                    gen_random_uuid(), {{caregiverUserId}}, 'CAREGIVER', 0, 0,
                    'VND', now(), now())
                ON CONFLICT (user_id) WHERE account_type = 'CAREGIVER' AND user_id IS NOT NULL
                DO NOTHING
                """, ct);

            var feeEntry = LedgerEntry.Create("PLATFORM_FEE",
                "escrow:platform", "revenue:platform", platformFeeAmount, bookingId);
            if (feeEntry.IsFailure) return feeEntry.Error;
            feeEntry.Value.MarkPosted();

            var earningEntry = LedgerEntry.Create("CAREGIVER_EARNING",
                "escrow:platform", $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId);
            if (earningEntry.IsFailure) return earningEntry.Error;
            earningEntry.Value.MarkPosted();

            db.LedgerEntries.Add(feeEntry.Value);
            db.LedgerEntries.Add(earningEntry.Value);
            await db.SaveChangesAsync(ct);

            var credited = await db.Database.ExecuteSqlInterpolatedAsync($$"""
                UPDATE payments.wallet_accounts
                SET available_balance = available_balance + {{caregiverAmount}}, updated_at = now()
                WHERE user_id = {{caregiverUserId}} AND account_type = 'CAREGIVER'
                """, ct);
            if (credited != 1)
                return Error.Failure("payments.wallet_credit_failed", "Không thể ghi có ví caregiver.");

            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct);
            if (committedByOtherRequest) return Result.Success();
            throw;
        }
    }

    public async Task<Result> ReleaseEscrowAsync(Guid bookingId, long amount, CancellationToken ct = default)
    {
        var lockEntry = await db.LedgerEntries.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId
                && x.TransactionType == "ESCROW_LOCK", ct);
        if (lockEntry is null)
            return Result.Success();

        var alreadyReleased = await db.LedgerEntries.AsNoTracking()
            .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
        if (alreadyReleased)
            return Result.Success();

        var refund = LedgerEntry.Create("REFUND",
            "escrow:platform", "customer:escrow", lockEntry.Amount, bookingId,
            metadata: "{\"reason\":\"compensating_release_after_confirm_failure\"}");
        if (refund.IsFailure)
            return refund.Error;
        refund.Value.MarkPosted();

        db.LedgerEntries.Add(refund.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            var committedByOtherRequest = await db.LedgerEntries.AsNoTracking()
                .AnyAsync(x => x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
            if (!committedByOtherRequest) throw;
        }

        return Result.Success();
    }

    public async Task<Result> RefundToCustomerWalletAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default)
    {
        // REFUND là chốt idempotency. Không tạo hoặc cộng tiền vào ví lần hai.
        if (await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "REFUND", ct))
            return Result.Success();

        var lockEntry = await db.LedgerEntries.AsNoTracking().SingleOrDefaultAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "ESCROW_LOCK", ct);
        if (lockEntry is null || lockEntry.Amount == 0)
            return Result.Success();

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            // Re-check inside the transaction because Hangfire retries can overlap.
            if (await db.LedgerEntries.AnyAsync(x =>
                    x.BookingId == bookingId && x.TransactionType == "REFUND", ct))
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
                x.UserId == customerId && x.AccountType == "CUSTOMER", ct);
            if (wallet is null)
            {
                var created = WalletAccount.Create(customerId, "CUSTOMER");
                if (created.IsFailure) return created.Error;
                wallet = created.Value;
                db.WalletAccounts.Add(wallet);
            }

            var credit = wallet.AddAvailable(lockEntry.Amount);
            if (credit.IsFailure) return credit.Error;

            var refund = LedgerEntry.Create(
                "REFUND",
                "escrow:platform",
                $"wallet:customer:{customerId}",
                lockEntry.Amount,
                bookingId,
                metadata: "{\"reason\":\"no_caregiver_available_credit_to_customer_wallet\"}");
            if (refund.IsFailure) return refund.Error;
            refund.Value.MarkPosted();

            db.LedgerEntries.Add(refund.Value);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            // Nếu request cạnh tranh đã ghi REFUND thì số dư đã được ghi trong
            // cùng transaction của request đó; coi như thành công.
            var refundedByOtherRequest = await db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "REFUND", ct);
            if (refundedByOtherRequest) return Result.Success();
            throw;
        }
    }

    public async Task<Result> ResolveDisputeAsync(
        Guid bookingId,
        Guid customerId,
        Guid caregiverId,
        long escrowAmount,
        long platformFeeAmount,
        string decision,
        long? refundAmount,
        long? caregiverPenaltyAmount,
        CancellationToken ct = default)
    {
        if (escrowAmount <= 0 || platformFeeAmount < 0 || platformFeeAmount > escrowAmount)
            return Error.Validation("payments.dispute.amounts", "Số tiền escrow không hợp lệ.");

        var normalizedDecision = decision.Trim().ToUpperInvariant();
        long refund;
        switch (normalizedDecision)
        {
            case "CUSTOMER_WINS":
                refund = escrowAmount;
                break;
            case "CAREGIVER_WINS":
                refund = 0;
                break;
            case "PARTIAL_REFUND":
                if (refundAmount is null || refundAmount <= 0 || refundAmount >= escrowAmount)
                    return Error.Validation("payments.dispute.refund",
                        "Hoàn tiền một phần phải lớn hơn 0 và nhỏ hơn escrow.");
                refund = refundAmount.Value;
                break;
            default:
                return Error.Validation("payments.dispute.decision", "Phán quyết không hợp lệ.");
        }

        var requestedPenalty = caregiverPenaltyAmount ?? 0;
        if (requestedPenalty < 0)
            return Error.Validation("payments.dispute.penalty",
                "Mức phạt caregiver không được âm.");

        var remaining = escrowAmount - refund;
        var fee = Math.Min(platformFeeAmount, remaining);
        var maximumPenalty = Math.Max(0, remaining - fee);
        // Only a partial split can deduct a penalty from the caregiver's share.
        // For a full customer/caregiver win the value remains an administrative
        // dispute outcome; it must not create money outside the locked escrow.
        var penalty = normalizedDecision == "PARTIAL_REFUND" ? requestedPenalty : 0;
        if (penalty > maximumPenalty)
            return Error.Validation("payments.dispute.penalty",
                "Mức phạt caregiver vượt quá phần thu nhập còn lại.");
        var caregiverAmount = remaining - fee - penalty;

        var caregiverUserId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (caregiverUserId is null)
            return Error.NotFound("payments.caregiver_not_found", "Không tìm thấy tài khoản caregiver.");

        if (db.Database.IsRelational())
            return await ResolveDisputeRelationalAsync(
                bookingId, customerId, caregiverUserId.Value,
                normalizedDecision, refund, fee, penalty, caregiverAmount, ct);

        var alreadyResolved = await HasDisputeResolutionMarkerAsync(
            bookingId, normalizedDecision, ct);
        if (alreadyResolved) return Result.Success();

        if (refund > 0)
        {
            var customerWallet = await GetOrCreateWalletAsync(customerId, "CUSTOMER", ct);
            var credited = customerWallet.AddAvailable(refund);
            if (credited.IsFailure) return credited.Error;
            var entry = CreatePostedEntry("REFUND", "escrow:platform",
                $"wallet:customer:{customerId}", refund, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (caregiverAmount > 0)
        {
            var caregiverWallet = await GetOrCreateWalletAsync(caregiverUserId.Value, "CAREGIVER", ct);
            var credited = caregiverWallet.AddAvailable(caregiverAmount);
            if (credited.IsFailure) return credited.Error;
            var entry = CreatePostedEntry("CAREGIVER_EARNING", "escrow:platform",
                $"wallet:caregiver:{caregiverUserId.Value}", caregiverAmount, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (fee > 0)
        {
            var entry = CreatePostedEntry("PLATFORM_FEE", "escrow:platform",
                "revenue:platform", fee, bookingId,
                $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        if (penalty > 0)
        {
            var entry = CreatePostedEntry("PENALTY",
                $"wallet:caregiver:{caregiverUserId.Value}", "revenue:platform",
                penalty, bookingId, $"{{\"decision\":\"{normalizedDecision}\"}}");
            if (entry.IsFailure) return entry.Error;
            db.LedgerEntries.Add(entry.Value);
        }

        await db.SaveChangesAsync(ct);
        return Result.Success();
    }

    private async Task<Result> ResolveDisputeRelationalAsync(
        Guid bookingId,
        Guid customerId,
        Guid caregiverUserId,
        string decision,
        long refund,
        long fee,
        long penalty,
        long caregiverAmount,
        CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        try
        {
            await AcquirePaymentLockAsync(bookingId, ct);
            if (await HasDisputeResolutionMarkerAsync(bookingId, decision, ct))
            {
                await tx.CommitAsync(ct);
                return Result.Success();
            }

            if (refund > 0)
            {
                await EnsureWalletAsync(customerId, "CUSTOMER", ct);
                await db.Database.ExecuteSqlInterpolatedAsync($$"""
                    UPDATE payments.wallet_accounts
                    SET available_balance = available_balance + {{refund}}, updated_at = now()
                    WHERE user_id = {{customerId}} AND account_type = 'CUSTOMER'
                    """, ct);
                var entry = CreatePostedEntry("REFUND", "escrow:platform",
                    $"wallet:customer:{customerId}", refund, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (caregiverAmount > 0)
            {
                await EnsureWalletAsync(caregiverUserId, "CAREGIVER", ct);
                await db.Database.ExecuteSqlInterpolatedAsync($$"""
                    UPDATE payments.wallet_accounts
                    SET available_balance = available_balance + {{caregiverAmount}}, updated_at = now()
                    WHERE user_id = {{caregiverUserId}} AND account_type = 'CAREGIVER'
                    """, ct);
                var entry = CreatePostedEntry("CAREGIVER_EARNING", "escrow:platform",
                    $"wallet:caregiver:{caregiverUserId}", caregiverAmount, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (fee > 0)
            {
                var entry = CreatePostedEntry("PLATFORM_FEE", "escrow:platform",
                    "revenue:platform", fee, bookingId,
                    $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            if (penalty > 0)
            {
                var entry = CreatePostedEntry("PENALTY",
                    $"wallet:caregiver:{caregiverUserId}", "revenue:platform",
                    penalty, bookingId, $"{{\"decision\":\"{decision}\"}}");
                if (entry.IsFailure) return entry.Error;
                db.LedgerEntries.Add(entry.Value);
            }

            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        catch (DbUpdateException)
        {
            await tx.RollbackAsync(ct);
            db.ChangeTracker.Clear();
            if (await HasDisputeResolutionMarkerAsync(bookingId, decision, ct))
                return Result.Success();
            throw;
        }
    }

    public async Task<Result> ReleaseMatureSettlementAsync(
        Guid bookingId,
        Guid caregiverId,
        long escrowAmount,
        long platformFeeAmount,
        DateTimeOffset releasedAt,
        CancellationToken ct = default)
    {
        if (await disputeLookup.HasOpenDisputeAsync(bookingId, ct))
            return Error.Conflict("payments.settlement.not_mature",
                "Settlement chưa đến hạn hoặc booking đang có dispute.");

        // Booking owns maturity/status validation and stamps SettlementReleasedAt
        // after this idempotent Payments operation succeeds.
        return await SettleAsync(
            bookingId, caregiverId, escrowAmount, platformFeeAmount, ct);
    }

    private Task AcquirePaymentLockAsync(Guid bookingId, CancellationToken ct) =>
        db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({bookingId.ToString()}, 0))", ct);

    private Task<bool> HasDisputeResolutionMarkerAsync(
        Guid bookingId, string decision, CancellationToken ct) =>
        decision == "CAREGIVER_WINS"
            ? db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING", ct)
            : db.LedgerEntries.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.TransactionType == "REFUND", ct);

    private async Task<WalletAccount> GetOrCreateWalletAsync(
        Guid userId, string accountType, CancellationToken ct)
    {
        var wallet = await db.WalletAccounts.SingleOrDefaultAsync(x =>
            x.UserId == userId && x.AccountType == accountType, ct);
        if (wallet is not null) return wallet;
        wallet = WalletAccount.Create(userId, accountType).Value;
        db.WalletAccounts.Add(wallet);
        return wallet;
    }

    private Task<int> EnsureWalletAsync(Guid userId, string accountType, CancellationToken ct) =>
        db.Database.ExecuteSqlInterpolatedAsync($$"""
            INSERT INTO payments.wallet_accounts (
                id, user_id, account_type, available_balance, pending_balance,
                currency, created_at, updated_at)
            VALUES (gen_random_uuid(), {{userId}}, {{accountType}}, 0, 0, 'VND', now(), now())
            ON CONFLICT DO NOTHING
            """, ct);

    private static Result<LedgerEntry> CreatePostedEntry(
        string type, string debit, string credit, long amount,
        Guid bookingId, string metadata)
    {
        var entry = LedgerEntry.Create(type, debit, credit, amount, bookingId, metadata: metadata);
        if (entry.IsFailure) return entry.Error;
        var posted = entry.Value.MarkPosted();
        return posted.IsFailure ? posted.Error : entry.Value;
    }
}
