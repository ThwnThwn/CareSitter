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

    /// <summary>Allowed values: 'CREATED', 'PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'EXPIRED'.</summary>
    public string Status { get; private set; } = null!;

    public string? ProviderTransactionId { get; private set; }
    public string IdempotencyKey { get; private set; } = null!;
    public string? RequestPayload { get; private set; }
    public string? ResponsePayload { get; private set; }

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

    public Result MarkSucceeded(string? providerTransactionId = null, string? responsePayload = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> SUCCEEDED.");
        Status = "SUCCEEDED";
        ProviderTransactionId = providerTransactionId;
        ResponsePayload = responsePayload;
        return Result.Success();
    }

    public Result MarkFailed(string? responsePayload = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> FAILED.");
        Status = "FAILED";
        ResponsePayload = responsePayload;
        return Result.Success();
    }

    public Result MarkPending()
    {
        if (Status != "CREATED")
            return Error.Conflict("payment_intent.status", $"Khong the chuyen {Status} -> PENDING.");
        Status = "PENDING";
        return Result.Success();
    }
}
