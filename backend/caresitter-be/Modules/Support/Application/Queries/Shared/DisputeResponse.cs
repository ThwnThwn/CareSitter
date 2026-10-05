namespace CareSitter.Modules.Support.Application;

public sealed record DisputeResponse(Guid Id, Guid BookingId, Guid RaisedByUserId,
    string? Reason, string? Description, string Status, string? Decision,
    long? RefundAmount, DateTimeOffset OpenedAt, DateTimeOffset? ResolvedAt);
