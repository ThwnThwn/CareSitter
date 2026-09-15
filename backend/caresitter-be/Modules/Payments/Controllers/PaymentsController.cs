using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>
/// Quản lý thanh toán: tạo Payment Intent, kiểm tra trạng thái,
/// xem số dư ví và lịch sử sổ cái (ledger).
/// </summary>
[ApiController]
[Authorize]
public sealed class PaymentsController(
    PaymentsDbContext db,
    BookingDbContext bookingDb,
    IPeopleLookupService people,
    ICurrentUser currentUser,
    IVNPayService vnPay,
    IPaymentFinalizationService finalizer,
    IOptions<VNPayOptions> vnPayOptions) : ControllerBase
{
    // ════════════════════════════════════════════
    //  PAYMENT INTENTS
    // ════════════════════════════════════════════

    /// <summary>
    /// Tạo Payment Intent mới để khởi động thanh toán (idempotent theo booking + user).
    /// Nếu đã tạo trước đó với cùng idempotency key, trả về intent cũ.
    /// </summary>
    [HttpPost("api/v1/payments/intents")]
    public async Task<IActionResult> CreateIntent([FromBody] CreatePaymentIntentRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var booking = await bookingDb.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == req.BookingId && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();
        var beneficiaryName = (await people.GetBeneficiaryDisplayAsync(booking.BeneficiaryId, ct))?.DisplayName;
        if (booking.Status != BookingStatus.PendingPayment)
            return Conflict(new { error = "Booking khong o trạng thái cho thanh toan." });
        var now = DateTimeOffset.UtcNow;
        if (booking.PaymentDeadline <= now)
            return Conflict(new
            {
                error = "Booking da het thoi han thanh toan va dang cho doi soat.",
                code = "BOOKING_PAYMENT_DEADLINE_EXPIRED",
                paymentDeadline = booking.PaymentDeadline
            });
        var paymentTimeout = TimeSpan.FromMinutes(
            Math.Clamp(vnPayOptions.Value.PaymentTimeoutMinutes, 1, 60));

        // VNPay khong cho dung lai vnp_TxnRef. Chi tao ref moi khi attempt cu
        // da thất bại/het han; neu van con trong cua so xu ly thi bao ro cho user.
        var latestAttempt = await db.PaymentIntents
            .Where(x => x.BookingId == req.BookingId && x.CustomerId == userId && x.Provider == "VNPAY")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync(ct);
        if (latestAttempt?.Status == "SUCCEEDED")
            return Conflict(new { error = "Booking da thanh toan thành công.", code = "PAYMENT_ALREADY_SUCCEEDED" });
        if (latestAttempt?.Status == "PENDING")
        {
            VNPayQueryResult query;
            try
            {
                query = await vnPay.QueryTransactionAsync(latestAttempt, vnPayOptions.Value, ct);
            }
            catch
            {
                return Conflict(new
                {
                    error = "Chua the xac minh trạng thái giao dịch truoc. Vui long thu lai sau.",
                    code = "PAYMENT_STATUS_UNKNOWN"
                });
            }

            if (query.State == VNPayQueryState.Succeeded)
            {
                var finalized = await finalizer.FinalizeSuccessfulPaymentAsync(latestAttempt.Id,
                    query.TransactionId, query.RawPayload, PaymentFinalizationSource.RetryPreflight, ct);
                return Conflict(new
                {
                    error = finalized.Succeeded
                        ? "giao dịch truoc da thanh toan thành công."
                        : "giao dịch da thành công nhung booking chua the chot tu dong.",
                    code = finalized.Succeeded ? "PAYMENT_ALREADY_SUCCEEDED" : "PAYMENT_NEEDS_REVIEW"
                });
            }
            if (query.State is VNPayQueryState.Processing or VNPayQueryState.Unknown)
            {
                var expiresAt = latestAttempt.CreatedAt.Add(paymentTimeout);
                return Conflict(new
                {
                    error = query.State == VNPayQueryState.Processing
                        ? "Giao dịch trước vẫn đang được VNPay xử lý."
                        : "VNPay chưa trả về trạng thái chắc chắn cho giao dịch trước.",
                    code = query.State == VNPayQueryState.Processing
                        ? "PAYMENT_IN_PROGRESS"
                        : "PAYMENT_STATUS_UNKNOWN",
                    expiresAt
                });
            }

            await using var closeTx = await bookingDb.Database.BeginTransactionAsync(ct);
            var lockedBooking = await bookingDb.Bookings.FromSqlInterpolated(
                $"SELECT * FROM booking.bookings WHERE id = {booking.Id} FOR UPDATE")
                .SingleAsync(ct);
            if (lockedBooking.Status != BookingStatus.PendingPayment)
                return Conflict(new
                {
                    error = "Booking đã được tiến trình đối soát khác xử lý.",
                    code = "PAYMENT_STATE_CHANGED"
                });
            var closedStatus = query.State == VNPayQueryState.NotFound ? "EXPIRED" : "FAILED";
            var updated = await bookingDb.Database.ExecuteSqlInterpolatedAsync($$"""
                UPDATE payments.payment_intents
                SET status = {{closedStatus}}, response_payload = CAST({{query.RawPayload}} AS jsonb),
                    finalized_source = 'RetryPreflight', next_reconciliation_at = NULL,
                    updated_at = now()
                WHERE id = {{latestAttempt.Id}} AND status = 'PENDING'
                """, ct);
            if (updated == 0)
                return Conflict(new
                {
                    error = "Trạng thái giao dịch vừa thay đổi. Vui lòng tải lại booking.",
                    code = "PAYMENT_STATE_CHANGED"
                });
            await closeTx.CommitAsync(ct);
            db.ChangeTracker.Clear();
        }

        CaregiverSlotHold? createdHold = null;
        if (booking.CaregiverId is { } caregiverId)
        {
            var holdUntil = booking.PaymentDeadline.AddMinutes(
                Math.Clamp(vnPayOptions.Value.ReconciliationWindowMinutes, 1, 60));
            var existingHold = await bookingDb.CaregiverSlotHolds
                .SingleOrDefaultAsync(x => x.BookingId == booking.Id && x.Status == "HELD", ct);
            if (existingHold is not null && existingHold.CaregiverId == caregiverId)
            {
                existingHold.ExtendUntil(holdUntil);
                await bookingDb.SaveChangesAsync(ct);
            }
            else if (existingHold is not null)
            {
                existingHold.Release();
                await bookingDb.SaveChangesAsync(ct);
            }

            if (existingHold is null || existingHold.CaregiverId != caregiverId)
            {
                var holdResult = CaregiverSlotHold.Create(
                    booking.Id,
                    caregiverId,
                    booking.ScheduledStart,
                    booking.ScheduledEnd,
                    holdUntil);
                if (holdResult.IsFailure) return Problem(holdResult.Error);

                createdHold = holdResult.Value;
                bookingDb.CaregiverSlotHolds.Add(createdHold);
                try
                {
                    // Exclusion constraint trên caregiver + time range quyết định request thắng race.
                    await bookingDb.SaveChangesAsync(ct);
                }
                catch (DbUpdateException)
                {
                    return Conflict(new
                    {
                        error = "Caregiver đã được giữ chỗ cho booking khác trong cùng khung giờ.",
                        code = "CAREGIVER_TIME_SLOT_HELD"
                    });
                }
            }
        }

        var idempotencyKey = $"pi-{req.BookingId}-{userId}-VNPAY-{Guid.NewGuid():N}";
        var created = PaymentIntent.Create(req.BookingId, userId,
            "VNPAY", booking.EscrowAmount, idempotencyKey);
        if (created.IsFailure) return Problem(created.Error);

        var orderRef = $"CS{created.Value.Id:N}"[..34];
        var orderRefResult = created.Value.SetProviderOrderRef(orderRef);
        if (orderRefResult.IsFailure) return Problem(orderRefResult.Error);
        var pendingResult = created.Value.MarkPending();
        if (pendingResult.IsFailure) return Problem(pendingResult.Error);
        db.PaymentIntents.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            var raced = await db.PaymentIntents.AsNoTracking()
                .Where(x => x.BookingId == req.BookingId && x.CustomerId == userId &&
                    x.Provider == "VNPAY" && x.Status == "PENDING")
                .OrderByDescending(x => x.CreatedAt)
                .FirstOrDefaultAsync(ct);
            if (raced is not null)
                return Ok(ToIntentResponse(raced, vnPay, vnPayOptions.Value, beneficiaryName));
            if (createdHold is not null)
            {
                createdHold.Release();
                await bookingDb.SaveChangesAsync(ct);
            }
            throw;
        }
        return Created($"/api/v1/payments/intents/{created.Value.Id}",
            ToIntentResponse(created.Value, vnPay, vnPayOptions.Value, beneficiaryName));
    }

    /// <summary>Xem chi tiết một Payment Intent theo ID, chỉ hiển thị nếu thuộc user hiện tại.</summary>
    [HttpGet("api/v1/payments/intents/{id:guid}")]
    public async Task<IActionResult> GetIntent(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var intent = await db.PaymentIntents.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.CustomerId == userId, ct);
        if (intent is null) return NotFound();
        return Ok(ToIntentResponse(intent));
    }

    // ════════════════════════════════════════════
    //  WALLET
    // ════════════════════════════════════════════

    /// <summary>Xem số dư ví điện tử của user hiện tại (available + pending balance).</summary>
    [HttpGet("api/v1/wallet")]
    public async Task<IActionResult> GetMyWallet(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var accountType = currentUser.IsInRole("CAREGIVER") ? "CAREGIVER" : "CUSTOMER";
        var wallet = await db.WalletAccounts.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.AccountType == accountType, ct);
        if (wallet is null)
            return Ok(new WalletResponse(null, 0, 0, "VND"));
        return Ok(new WalletResponse(wallet.Id, wallet.AvailableBalance,
            wallet.PendingBalance, wallet.Currency));
    }

    /// <summary>Lấy các giao dịch liên quan đến ví của user hiện tại.</summary>
    [HttpGet("api/v1/wallet/transactions")]
    public async Task<IActionResult> ListMyWalletTransactions(
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var accountType = currentUser.IsInRole("CAREGIVER") ? "caregiver" : "customer";
        var walletAccount = $"wallet:{accountType}:{userId}";

        var query = db.LedgerEntries.AsNoTracking()
            .Where(x => x.DebitAccount == walletAccount || x.CreditAccount == walletAccount);
        var total = await query.CountAsync(ct);
        var entries = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return Ok(new
        {
            items = entries.Select(x => new WalletTransactionResponse(
                x.Id,
                x.BookingId,
                x.TransactionType,
                x.Amount,
                x.Currency,
                x.Status,
                x.CreditAccount == walletAccount ? "CREDIT" : "DEBIT",
                x.CreatedAt)),
            total,
            page,
            pageSize
        });
    }

    // ════════════════════════════════════════════
    //  LEDGER
    // ════════════════════════════════════════════

    /// <summary>Lấy lịch sử giao dịch sổ cái (ESCROW_LOCK, PAYOUT, SETTLEMENT...), có lọc theo booking.</summary>
    [HttpGet("api/v1/payments/ledger")]
    public async Task<IActionResult> ListLedger(Guid? bookingId = null,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = db.LedgerEntries.AsNoTracking().AsQueryable();
        if (bookingId.HasValue)
            query = query.Where(x => x.BookingId == bookingId.Value);

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return Ok(new
        {
            items = items.Select(e => new LedgerEntryResponse(e.Id, e.BookingId,
                e.PaymentIntentId, e.TransactionType, e.DebitAccount, e.CreditAccount,
                e.Amount, e.Currency, e.Status, e.CreatedAt)),
            total, page, pageSize
        });
    }

    // ── Helpers ──

    private static PaymentIntentResponse ToIntentResponse(
        PaymentIntent pi, IVNPayService? vnPay = null, VNPayOptions? options = null,
        string? beneficiaryName = null) =>
        new(pi.Id, pi.BookingId, pi.CustomerId, pi.Provider, pi.Amount, pi.Currency,
            pi.Status, pi.ProviderTransactionId, pi.IdempotencyKey, pi.CreatedAt,
            pi.ProviderOrderRef is not null && vnPay is not null && options is not null
                ? vnPay.BuildPaymentUrl(pi, options, beneficiaryName)
                : null,
            pi.ProviderOrderRef);

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

// ── DTOs ──
public sealed record CreatePaymentIntentRequest(Guid BookingId);
public sealed record PaymentIntentResponse(Guid Id, Guid BookingId, Guid CustomerId,
    string Provider, long Amount, string Currency, string Status,
    string? ProviderTransactionId, string IdempotencyKey, DateTimeOffset CreatedAt,
    string? PaymentUrl = null, string? ProviderOrderRef = null);
public sealed record WalletResponse(Guid? Id, long AvailableBalance, long PendingBalance, string Currency);
public sealed record WalletTransactionResponse(Guid Id, Guid? BookingId,
    string TransactionType, long Amount, string Currency, string Status,
    string Direction, DateTimeOffset CreatedAt);
public sealed record LedgerEntryResponse(Guid Id, Guid? BookingId, Guid? PaymentIntentId,
    string TransactionType, string DebitAccount, string CreditAccount,
    long Amount, string Currency, string Status, DateTimeOffset CreatedAt);
