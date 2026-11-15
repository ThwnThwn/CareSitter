using CareSitter.Contracts.IntegrationEvents;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Outbox;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.PaymentIntents;
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
    IPayOSPaymentPortal payOS,
    IOptions<VNPayOptions> vnPayOptions,
    IClock clock) : IPaymentPortal
{
    public async Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(
        Guid bookingId, Guid userId, string? customerName, CancellationToken ct = default, string provider = "VNPAY")
    {
        provider = provider?.Trim().ToUpperInvariant() ?? "";
        if (provider == "PAYOS") return await payOS.CreateIntentAsync(bookingId, userId, ct);
        if (provider != "VNPAY") return Error.Validation("payments.provider", "Phương thức thanh toán không hợp lệ.");
        if (string.IsNullOrWhiteSpace(vnPayOptions.Value.TmnCode) || string.IsNullOrWhiteSpace(vnPayOptions.Value.HashSecret))
            return Error.Validation("PAYMENT_PROVIDER_UNAVAILABLE", "Phương thức thanh toán này hiện chưa khả dụng.");
        var booking = await bookings.GetForCustomerAsync(bookingId, userId, ct);
        if (booking is null)
            return Error.NotFound("payments.booking_not_found", "Không tìm thấy booking.");
        var admission = PaymentIntentCreationPolicy.CheckBooking(booking, clock.UtcNow);
        if (admission is not null) return Conflict(admission);
        if (await paymentsDb.PaymentIntents.AnyAsync(x => x.BookingId == bookingId && x.Status == "SUCCEEDED", ct))
            return Conflict("Booking đã thanh toán thành công.", "PAYMENT_ALREADY_SUCCEEDED");
        if (await paymentsDb.PaymentIntents.AnyAsync(x => x.BookingId == bookingId &&
                x.Provider != "VNPAY" && (x.Status == "CREATED" || x.Status == "PENDING"), ct))
            return Conflict("Booking đang có giao dịch tại cổng khác. Hãy hoàn tất giao dịch đó trước.", "PAYMENT_PROVIDER_IN_PROGRESS");

        var paymentTimeout = TimeSpan.FromMinutes(
            Math.Clamp(vnPayOptions.Value.PaymentTimeoutMinutes, 1, 60));
        var latestAttempt = await paymentsDb.PaymentIntents
            .Where(x => x.BookingId == bookingId && x.CustomerId == userId && x.Provider == "VNPAY")
            .OrderByDescending(x => x.CreatedAt).FirstOrDefaultAsync(ct);
        var previous = PaymentIntentCreationPolicy.CheckPreviousAttempt(latestAttempt?.Status);
        if (previous is not null) return Conflict(previous);

        if (latestAttempt?.Status == "PENDING")
        {
            VNPayQueryResult query;
            try
            {
                query = await vnPay.QueryTransactionAsync(latestAttempt, vnPayOptions.Value, ct);
            }
            catch
            {
                return Conflict(PaymentIntentCreationPolicy.QueryUnavailable());
            }

            var retry = PaymentIntentCreationPolicy.EvaluateRetry(
                query.State, latestAttempt.CreatedAt, paymentTimeout);
            if (retry.Action == PaymentRetryAction.Finalize)
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(latestAttempt.Id,
                    query.TransactionId, query.RawPayload, PaymentFinalizationSource.RetryPreflight, ct);
                return Conflict(PaymentIntentCreationPolicy.FinalizationConflict(finalized.Succeeded));
            }

            if (retry.Action == PaymentRetryAction.Block)
                return Conflict(retry.Conflict!);

            var closedStatus = retry.Action == PaymentRetryAction.CloseExpired ? "EXPIRED" : "FAILED";
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
            bookingId, userId, "VNPAY", booking.CustomerPayableAmount, idempotencyKey,
            createdAt: clock.UtcNow);
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
            if (await paymentsDb.PaymentIntents.AsNoTracking().AnyAsync(x => x.BookingId == bookingId &&
                    (x.Status == "CREATED" || x.Status == "PENDING"), ct))
                return Conflict("Booking đang có giao dịch tại cổng khác.", "PAYMENT_PROVIDER_IN_PROGRESS");
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
        if (intent?.Provider == "PAYOS")
        {
            await payOS.RefreshAsync(intent.Id, ct);
            paymentsDb.ChangeTracker.Clear();
            intent = await paymentsDb.PaymentIntents.AsNoTracking().SingleAsync(x => x.Id == intentId, ct);
            return PayOSPaymentPortal.ToResponse(intent);
        }
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

    private static Result<PaymentIntentCreationOutcome> Conflict(PaymentIntentConflict conflict) =>
        new PaymentIntentCreationOutcome(null, false, conflict);

    private static PaymentIntentResponse ToResponse(
        PaymentIntent intent, IVNPayService? service = null, VNPayOptions? options = null,
        string? customerName = null) => new(
        intent.Id, intent.BookingId, intent.CustomerId, intent.Provider, intent.Amount,
        intent.Currency, intent.Status, intent.ProviderTransactionId,
        intent.IdempotencyKey, intent.CreatedAt,
        intent.ProviderOrderRef is not null && intent.ProviderCreateDate is not null &&
            service is not null && options is not null
            ? service.BuildPaymentUrl(intent, options, customerName) : null,
        intent.ProviderOrderRef);
}
