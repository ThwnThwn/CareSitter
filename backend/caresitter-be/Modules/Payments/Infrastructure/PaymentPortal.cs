using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PaymentPortal(
    PaymentsDbContext paymentsDb,
    IBookingPaymentGateway bookings,
    IVNPayService vnPay,
    IPaymentFinalizationService finalizer,
    IPaymentOutboxDispatcher outbox,
    IOptions<VNPayOptions> vnPayOptions,
    IClock clock) : IPaymentPortal
{
    public async Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(
        Guid bookingId, Guid userId, string? customerName, CancellationToken ct = default)
    {
        var booking = await bookings.GetForCustomerAsync(bookingId, userId, ct);
        if (booking is null)
            return Error.NotFound("payments.booking_not_found", "Không tìm thấy booking.");
        if (booking.State != BookingPaymentState.PendingPayment)
            return Conflict("Booking khong o trạng thái cho thanh toan.");
        if (booking.PaymentDeadline <= clock.UtcNow)
            return Conflict("Booking da het thoi han thanh toan va dang cho doi soat.",
                "BOOKING_PAYMENT_DEADLINE_EXPIRED", paymentDeadline: booking.PaymentDeadline);

        var paymentTimeout = TimeSpan.FromMinutes(
            Math.Clamp(vnPayOptions.Value.PaymentTimeoutMinutes, 1, 60));
        var latestAttempt = await paymentsDb.PaymentIntents
            .Where(x => x.BookingId == bookingId && x.CustomerId == userId && x.Provider == "VNPAY")
            .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        if (latestAttempt?.Status == "SUCCEEDED")
            return Conflict("Booking da thanh toan thành công.", "PAYMENT_ALREADY_SUCCEEDED");

        if (latestAttempt?.Status == "PENDING")
        {
            VNPayQueryResult query;
            try
            {
                query = await vnPay.QueryTransactionAsync(latestAttempt, vnPayOptions.Value, ct);
            }
            catch
            {
                return Conflict(
                    "Chua the xac minh trạng thái giao dịch truoc. Vui long thu lai sau.",
                    "PAYMENT_STATUS_UNKNOWN");
            }

            if (query.State == VNPayQueryState.Succeeded)
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(latestAttempt.Id,
                    query.TransactionId, query.RawPayload, PaymentFinalizationSource.RetryPreflight, ct);
                return finalized.Succeeded
                    ? Conflict("giao dịch truoc da thanh toan thành công.",
                        "PAYMENT_ALREADY_SUCCEEDED")
                    : Conflict("giao dịch da thành công nhung booking chua the chot tu dong.",
                        "PAYMENT_NEEDS_REVIEW");
            }

            if (query.State is VNPayQueryState.Processing or VNPayQueryState.Unknown)
                return Conflict(
                    query.State == VNPayQueryState.Processing
                        ? "Giao dịch trước vẫn đang được VNPay xử lý."
                        : "VNPay chưa trả về trạng thái chắc chắn cho giao dịch trước.",
                    query.State == VNPayQueryState.Processing
                        ? "PAYMENT_IN_PROGRESS" : "PAYMENT_STATUS_UNKNOWN",
                    expiresAt: latestAttempt.CreatedAt.Add(paymentTimeout));

            var closedStatus = query.State == VNPayQueryState.NotFound ? "EXPIRED" : "FAILED";
            var closeStatus = await ClosePendingIntentAsync(
                latestAttempt.Id, closedStatus, query.RawPayload,
                PaymentFinalizationSource.RetryPreflight.ToString(), ct);
            if (closeStatus != BookingPaymentMutationStatus.Succeeded)
                return Conflict(
                    closeStatus == BookingPaymentMutationStatus.IntentStateChanged
                        ? "Trạng thái giao dịch vừa thay đổi. Vui lòng tải lại booking."
                        : "Booking đã được tiến trình đối soát khác xử lý.",
                    "PAYMENT_STATE_CHANGED");
            paymentsDb.ChangeTracker.Clear();
        }

        var hold = await bookings.EnsureSlotHoldAsync(
            booking.BookingId, vnPayOptions.Value.ReconciliationWindowMinutes, ct);
        if (hold.Status == BookingPaymentMutationStatus.CaregiverSlotHeld)
            return Conflict(
                "Caregiver đã được giữ chỗ cho booking khác trong cùng khung giờ.",
                "CAREGIVER_TIME_SLOT_HELD");
        if (hold.Status != BookingPaymentMutationStatus.Succeeded)
            return Conflict("Booking đã được tiến trình khác xử lý.", "PAYMENT_STATE_CHANGED");

        var idempotencyKey = $"pi-{bookingId}-{userId}-VNPAY-{Guid.NewGuid():N}";
        var created = PaymentIntent.Create(
            bookingId, userId, "VNPAY", booking.CustomerPayableAmount, idempotencyKey);
        if (created.IsFailure) return created.Error;
        var orderRef = $"CS{created.Value.Id:N}"[..34];
        var orderRefResult = created.Value.SetProviderOrderRef(orderRef);
        if (orderRefResult.IsFailure) return orderRefResult.Error;
        var pending = created.Value.MarkPending();
        if (pending.IsFailure) return pending.Error;
        paymentsDb.PaymentIntents.Add(created.Value);
        try
        {
            await paymentsDb.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            paymentsDb.ChangeTracker.Clear();
            var raced = await paymentsDb.PaymentIntents.AsNoTracking()
                .Where(x => x.BookingId == bookingId && x.CustomerId == userId &&
                    x.Provider == "VNPAY" && x.Status == "PENDING")
                .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);
            if (raced is not null)
                return new PaymentIntentCreationOutcome(
                    ToResponse(raced, vnPay, vnPayOptions.Value, customerName), false);
            if (hold.CreatedHoldId is { } holdId)
                await bookings.ReleaseSlotHoldAsync(booking.BookingId, holdId, ct);
            throw;
        }

        return new PaymentIntentCreationOutcome(
            ToResponse(created.Value, vnPay, vnPayOptions.Value, customerName), true);
    }

    public async Task<PaymentIntentResponse?> GetIntentAsync(
        Guid intentId, Guid userId, CancellationToken ct = default)
    {
        var intent = await paymentsDb.PaymentIntents.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == intentId && x.CustomerId == userId, ct);
        return intent is null ? null : ToResponse(intent);
    }

    public async Task<WalletResponse> GetWalletAsync(
        Guid userId, string accountType, CancellationToken ct = default)
    {
        var wallet = await paymentsDb.WalletAccounts.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.AccountType == accountType, ct);
        return wallet is null ? new WalletResponse(null, 0, 0, "VND")
            : new WalletResponse(wallet.Id, wallet.AvailableBalance,
                wallet.PendingBalance, wallet.Currency);
    }

    public async Task<PaymentPage<WalletTransactionResponse>> ListWalletTransactionsAsync(
        Guid userId, string accountType, int page, int pageSize, CancellationToken ct = default)
    {
        var walletAccount = $"wallet:{accountType}:{userId}";
        var query = paymentsDb.LedgerEntries.AsNoTracking()
            .Where(x => x.DebitAccount == walletAccount || x.CreditAccount == walletAccount);
        var total = await query.CountAsync(ct);
        var entries = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PaymentPage<WalletTransactionResponse>(entries.Select(x =>
            new WalletTransactionResponse(x.Id, x.BookingId, x.TransactionType,
                x.Amount, x.Currency, x.Status,
                x.CreditAccount == walletAccount ? "CREDIT" : "DEBIT", x.CreatedAt))
            .ToArray(), total, page, pageSize);
    }

    public async Task<PaymentPage<LedgerEntryResponse>> ListLedgerAsync(
        Guid? bookingId, int page, int pageSize, CancellationToken ct = default)
    {
        var query = paymentsDb.LedgerEntries.AsNoTracking().AsQueryable();
        if (bookingId.HasValue) query = query.Where(x => x.BookingId == bookingId.Value);
        var total = await query.CountAsync(ct);
        var entries = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new PaymentPage<LedgerEntryResponse>(entries.Select(x =>
            new LedgerEntryResponse(x.Id, x.BookingId, x.PaymentIntentId,
                x.TransactionType, x.DebitAccount, x.CreditAccount, x.Amount,
                x.Currency, x.Status, x.CreatedAt)).ToArray(), total, page, pageSize);
    }

    private async Task<BookingPaymentMutationStatus> ClosePendingIntentAsync(
        Guid intentId, string closedStatus, string payload, string source, CancellationToken ct)
    {
        paymentsDb.ChangeTracker.Clear();
        Guid? messageId = null;
        await using (var tx = await paymentsDb.Database.BeginTransactionAsync(ct))
        {
            var intent = await paymentsDb.PaymentIntents.FromSqlInterpolated(
                    $"SELECT * FROM payments.payment_intents WHERE id = {intentId} FOR UPDATE")
                .SingleOrDefaultAsync(ct);
            if (intent is null || intent.Status != "PENDING")
                return BookingPaymentMutationStatus.IntentStateChanged;

            var result = closedStatus == "EXPIRED"
                ? intent.MarkExpired(source, payload)
                : intent.MarkFailed(payload, source);
            if (result.IsFailure)
                return BookingPaymentMutationStatus.IntentStateChanged;

            var message = OutboxMessage.Create(
                new PaymentFailed(intent.BookingId, intent.Id, source));
            paymentsDb.OutboxMessages.Add(message);
            messageId = message.Id;
            await paymentsDb.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        }

        await outbox.DispatchAsync(messageId!.Value, ct);
        return BookingPaymentMutationStatus.Succeeded;
    }

    private static Result<PaymentIntentCreationOutcome> Conflict(
        string error, string? code = null, DateTimeOffset? paymentDeadline = null,
        DateTimeOffset? expiresAt = null) => new PaymentIntentCreationOutcome(
            null, false, new PaymentIntentConflict(error, code, paymentDeadline, expiresAt));

    private static PaymentIntentResponse ToResponse(
        PaymentIntent intent, IVNPayService? service = null, VNPayOptions? options = null,
        string? customerName = null) => new(
        intent.Id, intent.BookingId, intent.CustomerId, intent.Provider, intent.Amount,
        intent.Currency, intent.Status, intent.ProviderTransactionId,
        intent.IdempotencyKey, intent.CreatedAt,
        intent.ProviderOrderRef is not null && service is not null && options is not null
            ? service.BuildPaymentUrl(intent, options, customerName) : null,
        intent.ProviderOrderRef);
}
