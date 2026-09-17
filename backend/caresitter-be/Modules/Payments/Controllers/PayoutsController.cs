using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>
/// Quản lý các yêu cầu rút tiền (payout) của Caregiver từ ví điện tử.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/payments/payouts")]
public sealed class PayoutsController(
    PaymentsDbContext db,
    ICurrentUser currentUser,
    IEncryptionService encryption) : ControllerBase
{
    /// <summary>Caregiver tao yeu cau rut tien tu available balance.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreatePayoutRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var wallet = await db.WalletAccounts
            .FirstOrDefaultAsync(x => x.UserId == userId && x.AccountType == "CAREGIVER", ct);
        if (wallet is null)
            return BadRequest(new { error = "Caregiver chua co vi dien tu." });

        if (wallet.AvailableBalance < req.Amount)
            return BadRequest(new { error = "So du kha dung khong du." });

        var deductResult = wallet.DeductAvailable(req.Amount);
        if (deductResult.IsFailure) return Problem(deductResult.Error);

        var payout = PayoutRequest.Create(userId, wallet.Id, req.Amount,
            req.BankName, req.AccountHolderName, encryption.Encrypt(req.AccountNumber.Trim()));
        if (payout.IsFailure) return Problem(payout.Error);

        db.PayoutRequests.Add(payout.Value);
        await db.SaveChangesAsync(ct);

        return Created($"/api/v1/payments/payouts/{payout.Value.Id}",
            ToResponse(payout.Value));
    }

    /// <summary>Caregiver xem lich su rut tien cua minh (phan trang).</summary>
    [HttpGet]
    public async Task<IActionResult> ListMy(int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = db.PayoutRequests.AsNoTracking()
            .Where(x => x.CaregiverId == userId);

        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.RequestedAt)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .ToListAsync(ct);

        var responses = items.Select(x => ToResponse(x, revealAccountNumber: false)).ToList();

        return Ok(new { items = responses, total, page, pageSize });
    }

    /// <summary>Admin: danh sach yeu cau rut tien cho duyet (phan trang).</summary>
    [HttpGet("pending")]
    public async Task<IActionResult> ListPending(string? status = "PENDING",
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var query = db.PayoutRequests.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status) && !string.Equals(status, "ALL", StringComparison.OrdinalIgnoreCase))
            query = query.Where(x => x.Status == status.ToUpper());

        var total = await query.CountAsync(ct);
        var entities = await query.OrderBy(x => x.RequestedAt)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .ToListAsync(ct);

        return Ok(new { items = entities.Select(x => ToResponse(x, revealAccountNumber: true)), total, page, pageSize });
    }

    /// <summary>Admin duyet yeu cau rut tien va ghi so cai PAYOUT.</summary>
    [HttpPost("{id:guid}/approve")]
    public async Task<IActionResult> Approve(Guid id, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        if (currentUser.UserId is not { } adminId) return Unauthorized();

        var payout = await db.PayoutRequests.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (payout is null) return NotFound();

        var result = payout.Approve(adminId);
        if (result.IsFailure) return Problem(result.Error);

        var ledger = LedgerEntry.Create("PAYOUT",
            $"wallet:caregiver:{payout.CaregiverId}", "bank:external",
            payout.Amount, metadata: $"{{\"payout_request_id\":\"{payout.Id}\"}}");
        if (ledger.IsSuccess) db.LedgerEntries.Add(ledger.Value);

        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(payout));
    }

    /// <summary>Admin tu choi yeu cau rut tien va hoan lai so du kha dung.</summary>
    [HttpPost("{id:guid}/reject")]
    public async Task<IActionResult> Reject(Guid id, [FromBody] RejectPayoutRequest? req, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return Forbid();
        if (currentUser.UserId is not { } adminId) return Unauthorized();

        var payout = await db.PayoutRequests.SingleOrDefaultAsync(x => x.Id == id, ct);
        if (payout is null) return NotFound();

        var result = payout.Reject(adminId, req?.Reason);
        if (result.IsFailure) return Problem(result.Error);

        var wallet = await db.WalletAccounts
            .FirstOrDefaultAsync(x => x.Id == payout.WalletAccountId, ct);
        wallet?.AddAvailable(payout.Amount);

        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(payout));
    }

    // ── Helpers ──
    private PayoutResponse ToResponse(PayoutRequest p, bool revealAccountNumber = false) => new(p.Id, p.CaregiverId,
        p.WalletAccountId, p.Amount, p.BankName, p.AccountHolderName, p.Status,
        revealAccountNumber ? ReadAccountNumber(p.AccountNumberEncrypted) : MaskAccountNumber(ReadAccountNumber(p.AccountNumberEncrypted)),
        p.RequestedAt, p.ReviewedAt, p.RejectReason);

    private string ReadAccountNumber(string storedValue)
    {
        try { return encryption.Decrypt(storedValue); }
        catch (FormatException) { return storedValue; }
        catch (System.Security.Cryptography.CryptographicException) { return storedValue; }
    }

    private static string MaskAccountNumber(string value) => value.Length <= 4
        ? value
        : new string('•', value.Length - 4) + value[^4..];

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Forbidden => Forbid(),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

// ── DTOs ──
public sealed record CreatePayoutRequest(long Amount, string BankName,
    string AccountHolderName, string AccountNumber);
public sealed record RejectPayoutRequest(string? Reason);
public sealed record PayoutResponse(Guid Id, Guid CaregiverId, Guid WalletAccountId,
    long Amount, string BankName, string AccountHolderName, string Status,
    string AccountNumber, DateTimeOffset RequestedAt, DateTimeOffset? ReviewedAt, string? RejectReason);
