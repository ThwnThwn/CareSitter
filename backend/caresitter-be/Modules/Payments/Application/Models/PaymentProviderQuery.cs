namespace CareSitter.Modules.Payments.Application;

public enum PaymentProviderState { Succeeded, Processing, Failed, NotFound, Unknown }
public sealed record PaymentProviderQuery(PaymentProviderState State, string? TransactionId,
    string RawPayload, string? Message = null);
public sealed record PayOSPaymentLink(long OrderCode, long Amount, string PaymentLinkId,
    string CheckoutUrl, string AccountNumber, string RawPayload);
