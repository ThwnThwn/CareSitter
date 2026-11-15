using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using System.Globalization;

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
        string idempotencyKey,
        DateTimeOffset? createdAt) : base(id)
    {
        CreatedAt = createdAt ?? CreatedAt;
        UpdatedAt = CreatedAt;
        BookingId = bookingId;
        CustomerId = customerId;
        Provider = provider;
        Amount = amount;
        Currency = currency;
        IdempotencyKey = idempotencyKey;
        Status = "CREATED";
        if (provider == "VNPAY")
            ProviderCreateDate = CreatedAt.ToOffset(TimeSpan.FromHours(7))
                .ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture);
    }

    public Guid BookingId { get; private set; }
    public Guid CustomerId { get; private set; }

    /// <summary>Allowed values: 'VNPAY', 'PAYOS', 'MOMO', 'CARD'.</summary>
    public string Provider { get; private set; } = null!;

    public long Amount { get; private set; }
    public string Currency { get; private set; } = null!;

    /// <summary>Allowed values: 'CREATED', 'PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED', 'EXPIRED', 'SUPERSEDED'.</summary>
    public string Status { get; private set; } = null!;

    public string? ProviderTransactionId { get; private set; }
    public string? ProviderOrderRef { get; private set; }
    /// <summary>Exact immutable vnp_CreateDate used in the original payment URL.
    /// Legacy rows stay null; CreatedAt/PayDate are not safe substitutes.</summary>
    public string? ProviderCreateDate { get; private set; }
    public string? ProviderLinkId { get; private set; }
    public string? CheckoutUrl { get; private set; }
    public string? ProviderAccountNumber { get; private set; }
    public DateTimeOffset? ProviderExpiresAt { get; private set; }
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
        string currency = "VND",
        DateTimeOffset? createdAt = null)
    {
        if (string.IsNullOrWhiteSpace(provider))
            return Error.Validation("payment_intent.provider", "provider không được rỗng.");
        if (amount < 0)
            return Error.Validation("payment_intent.amount", "amount không được âm.");
        if (string.IsNullOrWhiteSpace(idempotencyKey))
            return Error.Validation("payment_intent.idempotency_key", "idempotency_key không được rỗng.");

        return new PaymentIntent(Guid.NewGuid(), bookingId, customerId, provider, amount, currency, idempotencyKey, createdAt);
    }

    public Result MarkSucceeded(string? providerTransactionId = null, string? responsePayload = null,
        string? finalizedSource = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"không thể chuyen {Status} -> SUCCEEDED.");
        Status = "SUCCEEDED";
        ProviderTransactionId = providerTransactionId;
        ResponsePayload = responsePayload;
        FinalizedSource = finalizedSource;
        ManualReviewReason = null;
        NextReconciliationAt = null;
        return Result.Success();
    }

    public Result MarkFailed(string? responsePayload = null, string? finalizedSource = null)
    {
        if (Status is not ("CREATED" or "PENDING"))
            return Error.Conflict("payment_intent.status", $"không thể chuyen {Status} -> FAILED.");
        Status = "FAILED";
        ResponsePayload = responsePayload;
        FinalizedSource = finalizedSource;
        NextReconciliationAt = null;
        return Result.Success();
    }

    public Result MarkPending()
    {
        if (Status != "CREATED")
            return Error.Conflict("payment_intent.status", $"không thể chuyen {Status} -> PENDING.");
        Status = "PENDING";
        return Result.Success();
    }

    public Result MarkExpired(string? finalizedSource = null, string? responsePayload = null)
    {
        if (Status != "PENDING")
            return Error.Conflict("payment_intent.status", $"không thể chuyen {Status} -> EXPIRED.");
        Status = "EXPIRED";
        FinalizedSource = finalizedSource;
        ResponsePayload = responsePayload;
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
            return Error.Validation("payment_intent.provider_order_ref", "provider_order_ref không được rỗng.");
        if (ProviderOrderRef is not null && ProviderOrderRef != providerOrderRef)
            return Error.Conflict("payment_intent.provider_order_ref", "Payment intent da co provider order ref.");
        ProviderOrderRef = providerOrderRef;
        return Result.Success();
    }

    public Result ConfigurePayOS(DateTimeOffset expiresAt)
    {
        if (Provider != "PAYOS" || Status != "CREATED" || expiresAt <= CreatedAt)
            return Error.Validation("payment_intent.payos_expiry", "Thời hạn thanh toán không hợp lệ.");
        ProviderExpiresAt = expiresAt;
        return Result.Success();
    }

    public Result AttachPayOSLink(string linkId, string checkoutUrl, string? accountNumber = null)
    {
        if (Provider != "PAYOS" || string.IsNullOrWhiteSpace(linkId) || string.IsNullOrWhiteSpace(checkoutUrl))
            return Error.Validation("payment_intent.payos_link", "Link thanh toán không hợp lệ.");
        if (ProviderLinkId is not null && ProviderLinkId != linkId)
            return Error.Conflict("payment_intent.payos_link", "Mã link thanh toán đã được gán.");
        ProviderLinkId = linkId;
        CheckoutUrl = checkoutUrl;
        ProviderAccountNumber ??= accountNumber;
        return Result.Success();
    }
}
