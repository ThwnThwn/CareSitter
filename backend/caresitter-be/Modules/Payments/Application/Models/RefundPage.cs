namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record RefundPage(
    IReadOnlyList<RefundResponse> Items,
    int Total,
    int Page,
    int PageSize);
