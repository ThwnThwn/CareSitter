using System.Globalization;
using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.PaymentIntents;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSCheckout(
    PaymentsDbContext db,
    IBookingPaymentGateway bookings,
    IPayOSService service,
    IPaymentFinalizationService finalizer,
    PayOSPaymentReconciliation reconciliation,
    IOptions<PayOSOptions> options,
    IOptions<VNPayOptions> timing,
    IClock clock)
{
    public async Task<Result<PaymentIntentCreationOutcome>> CreateIntentAsync(Guid bookingId,
        Guid userId, CancellationToken ct = default)
    {
        if (!options.Value.Enabled)
            return Error.Validation("PAYMENT_PROVIDER_UNAVAILABLE", "Phương thức thanh toán này hiện chưa khả dụng.");
        var booking = await bookings.GetForCustomerAsync(bookingId, userId, ct);
        if (booking is null) return Error.NotFound("payments.booking_not_found", "Không tìm thấy booking.");
        var admission = PaymentIntentCreationPolicy.CheckBooking(booking, clock.UtcNow);
        if (admission is not null) return Conflict(admission.Error, admission.Code);
        if (booking.CustomerPayableAmount <= 0)
            return Error.Validation("payments.amount", "Booking này không có số tiền cần thu qua cổng thanh toán.");
        if (await db.PaymentIntents.AnyAsync(x => x.BookingId == bookingId && x.Status == "SUCCEEDED", ct))
            return Conflict("Booking đã thanh toán thành công.", "PAYMENT_ALREADY_SUCCEEDED");

        var intent = await ActiveIntentAsync(bookingId, ct);
        if (intent is not null && intent.Provider != "PAYOS") return ProviderInProgress();
        var created = intent is null;
        if (intent is null)
        {
            var hold = await bookings.EnsureSlotHoldAsync(bookingId, timing.Value.ReconciliationWindowMinutes, ct);
            if (hold.Status != BookingPaymentMutationStatus.Succeeded)
                return Conflict("Chưa thể giữ chỗ cho booking. Vui lòng tải lại.", "PAYMENT_STATE_CHANGED");
            intent = PaymentIntent.Create(bookingId, userId, "PAYOS", booking.CustomerPayableAmount,
                $"payos-{Guid.NewGuid():N}", createdAt: clock.UtcNow).Value;
            var orderCode = (BitConverter.ToUInt64(RandomNumberGenerator.GetBytes(8)) & 0x1fffffffffffffUL) + 1;
            if (orderCode > 9_007_199_254_740_991UL) orderCode = 1;
            intent.SetProviderOrderRef(orderCode.ToString(CultureInfo.InvariantCulture));
            intent.ConfigurePayOS(booking.PaymentDeadline);
            intent.MarkPending();
            db.PaymentIntents.Add(intent);
            try { await db.SaveChangesAsync(ct); }
            catch (DbUpdateException exception) when (exception.InnerException is PostgresException { SqlState: "23505" })
            {
                db.ChangeTracker.Clear();
                intent = await ActiveIntentAsync(bookingId, ct);
                if (intent is null) throw;
                if (intent.Provider != "PAYOS") return ProviderInProgress();
                created = false;
            }
        }

        // Lưu mã đơn trước POST. Khi mất response, retry dùng đúng mã đã lưu.
        if (!created)
        {
            await reconciliation.RefreshAsync(intent.Id, ct);
            db.ChangeTracker.Clear();
            intent = await db.PaymentIntents.SingleAsync(x => x.Id == intent.Id, ct);
            if (intent.Status == "SUCCEEDED")
                return Conflict("Giao dịch đã thanh toán thành công.", "PAYMENT_ALREADY_SUCCEEDED");
            if (intent.Status != "PENDING")
                return Conflict("Giao dịch đã đóng. Vui lòng tải lại booking.", "PAYMENT_STATE_CHANGED");
            if (intent.CheckoutUrl is not null)
                return new PaymentIntentCreationOutcome(ToResponse(intent), false);
        }

        PayOSPaymentLink? link = null;
        try { link = await service.CreateLinkAsync(intent, ct); }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or InvalidDataException or
            JsonException or InvalidOperationException or FormatException or KeyNotFoundException)
        {
            if (ct.IsCancellationRequested) throw;
            var query = await service.QueryAsync(intent, ct);
            if (query.State == PaymentProviderState.Succeeded)
            {
                await finalizer.FinalizeSuccessfulPaymentAsync(intent.Id, query.TransactionId,
                    query.RawPayload, PaymentFinalizationSource.RetryPreflight, ct);
                return Conflict("Giao dịch đã được ghi nhận. Vui lòng tải lại booking.", "PAYMENT_ALREADY_SUCCEEDED");
            }
            if (query.State == PaymentProviderState.Processing && query.TransactionId is { } id)
                link = new(PayOSService.ParseOrderCode(intent.ProviderOrderRef), intent.Amount, id,
                    $"https://pay.payos.vn/web/{Uri.EscapeDataString(id)}", "", query.RawPayload);
            else
                return Conflict("Chưa xác minh được giao dịch. Hệ thống giữ nguyên mã thanh toán để tránh thu tiền hai lần.",
                    "PAYMENT_STATUS_UNKNOWN");
        }

        // Không ghi đè SUCCEEDED nếu webhook đến trong lúc POST đang trả response.
        db.ChangeTracker.Clear();
        await using (var tx = await db.Database.BeginTransactionAsync(ct))
        {
            var locked = await db.PaymentIntents.FromSqlInterpolated(
                $"SELECT * FROM payments.payment_intents WHERE id = {intent.Id} FOR UPDATE").SingleAsync(ct);
            var attached = locked.AttachPayOSLink(link.PaymentLinkId, link.CheckoutUrl,
                string.IsNullOrEmpty(link.AccountNumber) ? null : link.AccountNumber);
            if (attached.IsFailure) return attached.Error;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            intent = locked;
        }
        return new PaymentIntentCreationOutcome(ToResponse(intent), created);
    }

    private Task<PaymentIntent?> ActiveIntentAsync(Guid bookingId, CancellationToken ct) =>
        db.PaymentIntents.AsNoTracking().SingleOrDefaultAsync(x => x.BookingId == bookingId &&
            (x.Status == "CREATED" || x.Status == "PENDING"), ct);
    private static Result<PaymentIntentCreationOutcome> ProviderInProgress() =>
        Conflict("Booking đang có giao dịch tại cổng khác. Hãy hoàn tất hoặc hủy giao dịch đó trước.", "PAYMENT_PROVIDER_IN_PROGRESS");
    private static Result<PaymentIntentCreationOutcome> Conflict(string message, string? code) =>
        new PaymentIntentCreationOutcome(null, false, new PaymentIntentConflict(message, code));

    internal static PaymentIntentResponse ToResponse(PaymentIntent intent) => new(intent.Id,
        intent.BookingId, intent.CustomerId, intent.Provider, intent.Amount, intent.Currency, intent.Status,
        intent.ProviderTransactionId, intent.IdempotencyKey, intent.CreatedAt,
        intent.Status == "PENDING" ? intent.CheckoutUrl : null, intent.ProviderOrderRef);
}
