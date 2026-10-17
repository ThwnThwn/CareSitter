namespace CareSitter.Modules.Payments.Controllers;

public sealed record ConfirmRefundRequest(
    string ProviderRefundId,
    string ConfirmationNote);
