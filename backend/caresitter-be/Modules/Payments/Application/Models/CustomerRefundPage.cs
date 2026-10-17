namespace CareSitter.Modules.Payments.Application.Refunds;

public sealed record CustomerRefundResponse(
    Guid Id,
    Guid BookingId,
    string Provider,
    long Amount,
    string Currency,
    string Reason,
    string Status,
    DateTimeOffset RequestedAt,
    DateTimeOffset? CompletedAt);

public sealed record CustomerRefundPage(
    IReadOnlyList<CustomerRefundResponse> Items,
    int Total,
    int Page,
    int PageSize);
