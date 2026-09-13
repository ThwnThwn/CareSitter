using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Domain;

/// <summary>
/// Aggregate root cho 1 lan khoi tao thanh toan qua provider. Idempotent theo idempotency_key.
/// Map sang bang payment_intents.
/// </summary>
public sealed class PaymentIntent : AggregateRoot
{
    private PaymentIntent() { } // EF

    private PaymentIntent(
        Guid id,
        Guid bookingId,
        Guid customerId,
        string provider,
        long amount,
        string currency,
        string idempotencyKey) : base(id)
    {
        BookingId = bookingId;
        CustomerId = customerId;
        Provider = provider;
        Amount = amount;
        Currency = currency;
        IdempotencyKey = idempotencyKey;
        Status = "CREATED";
    }

    public Guid BookingId { get; private set; }
    public Guid CustomerId { get; private set; }

    /// <summary>Allowed values: 'VNPAY', 'MOMO', 'CARD'.</summary>
    public string Provider { get; private set; } = null!;

    public long Amount { get; private set; }
    public string Currency { get; private set; } = null!;

    /// <summary>Allowed values: 'CREATED', 'PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'EXPIRED', 'SUPERSEDED'.</summary>
    public string Status { get; private set; } = null!;

    public string? ProviderTransactionId { get; private set; }
    public string? ProviderOrderRef { get; private set; }
    public string IdempotencyKey { get; private set; } = null!;
    public string? RequestPayload { get; private set; }
    public string? ResponsePayload { get; private set; }
    public int ReconciliationAttempts { get; private set; }
    public DateTimeOffset? ReconciliationStartedAt { get; private set; }
    public DateTimeOffset? LastReconciliationAt { get; private set; }
    public DateTimeOffset? NextReconciliationAt { get; private set; }
    public string? LastReconciliationError { get; private set; }
    public string? FinalizedSource { get; private set; }
    public string? ManualReviewReason { get; private set; }

    public static Result<PaymentIntent> Create(
        Guid bookingId,
        Guid customerId,
        string provider,
        long amount,
        string idempotencyKey,
        string currency = "VND")
    {
        if (string.IsNullOrWhiteSpace(provider))
            return Error.Validation("payment_intent.provider", "provider khong duoc rong.");
        if (amount < 0)
            return Error.Validation("payment_intent.amount", "amount khong duoc am.");
        if (string.IsNullOrWhiteSpace(idempotencyKey))
            return Error.Validation("payment_intent.idempotency_key", "idempotency_key khong duoc rong.");

        return new PaymentIntent(Guid.NewGuid(), bookingId, customerId, provider, amount, currency, idempotencyKey);
    }

    public Result MarkSucceeded(string? providerTransactionId = null, string? responsePayload = null,
        string? finalizedSource = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> SUCCEEDED.");
        Status = "SUCCEEDED";
        ProviderTransactionId = providerTransactionId;
        ResponsePayload = responsePayload;
        FinalizedSource = finalizedSource;
        NextReconciliationAt = null;
        return Result.Success();
    }

    public Result MarkFailed(string? responsePayload = null, string? finalizedSource = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> FAILED.");
        Status = "FAILED";
        ResponsePayload = responsePayload;
        FinalizedSource = finalizedSource;
        NextReconciliationAt = null;
        return Result.Success();
    }

    public Result MarkPending()
    {
        if (Status != "CREATED")
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> PENDING.");
        Status = "PENDING";
        return Result.Success();
    }

    public Result MarkExpired(string? finalizedSource = null)
    {
        if (Status != "PENDING")
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> EXPIRED.");
        Status = "EXPIRED";
        FinalizedSource = finalizedSource;
        NextReconciliationAt = null;
        return Result.Success();
    }

    public Result RecordReconciliationAttempt(
        DateTimeOffset attemptedAt,
        DateTimeOffset? nextAttemptAt,
        string? error = null)
    {
        if (Status != "PENDING")
            return Error.Conflict("payment_intent.status", "Chi doi soat payment intent dang PENDING.");
        ReconciliationStartedAt ??= attemptedAt;
        LastReconciliationAt = attemptedAt;
        NextReconciliationAt = nextAttemptAt;
        LastReconciliationError = error;
        ReconciliationAttempts++;
        return Result.Success();
    }

    public Result MarkSuperseded()
    {
        if (Status != "PENDING") return Result.Success();
        Status = "SUPERSEDED";
        NextReconciliationAt = null;
        return Result.Success();
    }

    public void SetManualReviewReason(string reason)
    {
        ManualReviewReason = reason.Trim();
        NextReconciliationAt = null;
    }

    /// <summary>Gán mã đơn hàng duy nhất dùng để đối chiếu callback từ cổng thanh toán.</summary>
    public Result SetProviderOrderRef(string providerOrderRef)
    {
        if (string.IsNullOrWhiteSpace(providerOrderRef))
            return Error.Validation("payment_intent.provider_order_ref", "provider_order_ref khong duoc rong.");
        if (ProviderOrderRef is not null && ProviderOrderRef != providerOrderRef)
            return Error.Conflict("payment_intent.provider_order_ref", "Payment intent da co provider order ref.");
        ProviderOrderRef = providerOrderRef;
        return Result.Success();
    }
}
