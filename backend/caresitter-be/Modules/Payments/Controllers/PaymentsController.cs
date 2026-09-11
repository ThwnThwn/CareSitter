using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Booking.Domain;
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
    ICurrentUser currentUser,
    IVNPayService vnPay,
    IOptions<VNPayOptions> vnPayOptions) : ControllerBase
{
    private const int PaymentTimeoutMinutes = 15;
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
        var idempotencyKey = $"pi-{req.BookingId}-{userId}-VNPAY";

        var existing = await db.PaymentIntents.AsNoTracking()
            .FirstOrDefaultAsync(x => x.IdempotencyKey == idempotencyKey, ct);
        if (existing is not null)
            return Ok(ToIntentResponse(existing, vnPay, vnPayOptions.Value));

        if (booking.Status != BookingStatus.PendingPayment)
            return Conflict(new { error = "Booking khong o trang thai cho thanh toan." });

        CaregiverSlotHold? createdHold = null;
        if (booking.CaregiverId is { } caregiverId)
        {
            var holdResult = CaregiverSlotHold.Create(
                booking.Id,
                caregiverId,
                booking.ScheduledStart,
                booking.ScheduledEnd,
                DateTimeOffset.UtcNow.AddMinutes(PaymentTimeoutMinutes));
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
                    error = "Caregiver da duoc giu cho booking khac trong cung khung gio.",
                    code = "CAREGIVER_TIME_SLOT_HELD"
                });
            }
        }

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
            if (createdHold is not null)
            {
                createdHold.Release();
                await bookingDb.SaveChangesAsync(ct);
            }
            var raced = await db.PaymentIntents.AsNoTracking()
                .SingleOrDefaultAsync(x => x.IdempotencyKey == idempotencyKey, ct);
            if (raced is not null)
                return Ok(ToIntentResponse(raced, vnPay, vnPayOptions.Value));
            throw;
        }
        return Created($"/api/v1/payments/intents/{created.Value.Id}",
            ToIntentResponse(created.Value, vnPay, vnPayOptions.Value));
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
        var wallet = await db.WalletAccounts.AsNoTracking()
            .FirstOrDefaultAsync(x => x.UserId == userId, ct);
        if (wallet is null)
            return Ok(new WalletResponse(null, 0, 0, "VND"));
        return Ok(new WalletResponse(wallet.Id, wallet.AvailableBalance,
            wallet.PendingBalance, wallet.Currency));
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
        PaymentIntent pi, IVNPayService? vnPay = null, VNPayOptions? options = null) =>
        new(pi.Id, pi.BookingId, pi.CustomerId, pi.Provider, pi.Amount, pi.Currency,
            pi.Status, pi.ProviderTransactionId, pi.IdempotencyKey, pi.CreatedAt,
            pi.ProviderOrderRef is not null && vnPay is not null && options is not null
                ? vnPay.BuildPaymentUrl(pi, options)
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
public sealed record LedgerEntryResponse(Guid Id, Guid? BookingId, Guid? PaymentIntentId,
    string TransactionType, string DebitAccount, string CreditAccount,
    long Amount, string Currency, string Status, DateTimeOffset CreatedAt);
