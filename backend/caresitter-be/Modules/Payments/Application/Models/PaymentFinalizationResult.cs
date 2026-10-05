namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentFinalizationResult(bool Succeeded, string Code, string Message);
