using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.Controllers;

/// <summary>
/// Webhook endpoint: nhan IPN callback tu MoMo/VNPay.
/// Idempotent theo composite (provider, provider_event_id).
/// Khong RequireAuthorization — cong thanh toan goi truc tiep.
/// </summary>
[ApiController]
[Route("api/v1/payments/webhook")]
public sealed class WebhookController(PaymentsDbContext db) : ControllerBase
{
    /// <summary>Xử lý callback từ các cổng thanh toán (MoMo, VNPay, ZaloPay...).</summary>
    [HttpPost]
    public async Task<IActionResult> Handle([FromBody] WebhookRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Provider) || string.IsNullOrWhiteSpace(req.ProviderEventId))
            return BadRequest(new { error = "provider va provider_event_id la bat buoc." });

        bool alreadyReceived = await db.PaymentWebhooks.AsNoTracking()
            .AnyAsync(x => x.Provider == req.Provider && x.ProviderEventId == req.ProviderEventId, ct);
        if (alreadyReceived)
            return Ok(new { status = "ALREADY_PROCESSED" });

        var webhook = PaymentWebhook.Create(req.Provider, req.ProviderEventId,
            req.EventType, req.Payload);
        if (webhook.IsFailure)
            return BadRequest(new ProblemDetails { Title = webhook.Error.Code, Detail = webhook.Error.Message });
        db.PaymentWebhooks.Add(webhook.Value);

        if (req.EventType is "PAYMENT_SUCCESS" or "payment.success")
        {
            var intent = await db.PaymentIntents
                .FirstOrDefaultAsync(x => x.Provider == req.Provider
                    && x.Status != "SUCCEEDED" && x.Status != "FAILED", ct);

            if (intent is not null && !string.IsNullOrWhiteSpace(req.ProviderTransactionId))
            {
                var markResult = intent.MarkSucceeded(req.ProviderTransactionId, req.Payload);
                if (markResult.IsSuccess)
                {
                    var ledger = LedgerEntry.Create("ESCROW_LOCK",
                        $"customer:{intent.CustomerId}", "escrow:platform",
                        intent.Amount, intent.BookingId, intent.Id);
                    if (ledger.IsSuccess) db.LedgerEntries.Add(ledger.Value);
                }
            }
            webhook.Value.MarkProcessed();
        }
        else if (req.EventType is "PAYMENT_FAILED" or "payment.failed")
        {
            var intent = await db.PaymentIntents
                .FirstOrDefaultAsync(x => x.Provider == req.Provider
                    && x.Status != "SUCCEEDED" && x.Status != "FAILED", ct);
            intent?.MarkFailed(req.Payload);
            webhook.Value.MarkProcessed();
        }
        else
        {
            webhook.Value.MarkProcessed();
        }

        await db.SaveChangesAsync(ct);
        return Ok(new { status = "OK", webhookId = webhook.Value.Id });
    }
}

// ── DTOs ──
public sealed record WebhookRequest(string Provider, string ProviderEventId,
    string? EventType = null, string? ProviderTransactionId = null, string? Payload = null);
