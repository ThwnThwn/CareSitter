namespace CareSitter.Modules.Payments.Application.Payouts;

public sealed record PayoutPage(
    IReadOnlyList<PayoutResponse> Items,
    int Total,
    int Page,
    int PageSize);
