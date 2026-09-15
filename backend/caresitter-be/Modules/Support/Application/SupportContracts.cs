namespace CareSitter.Modules.Support.Application;

public sealed record DisputeResponse(Guid Id, Guid BookingId, Guid RaisedByUserId,
    string? Reason, string? Description, string Status, string? Decision,
    long? RefundAmount, DateTimeOffset OpenedAt, DateTimeOffset? ResolvedAt);

public sealed record NotificationResponse(Guid Id, string Type, string Title,
    string? Body, string? Data, DateTimeOffset? ReadAt, DateTimeOffset CreatedAt);

public sealed record MarkedNotificationsResponse(int Marked);

public sealed record ReviewResponse(Guid Id, Guid BookingId, Guid CaregiverId,
    Guid CustomerId, int Rating, string? Comment, string? ExperienceTags,
    DateTimeOffset CreatedAt);

public sealed record SupportTicketResponse(Guid Id, Guid UserId, Guid? BookingId,
    string Type, string Status, string Priority, string Title, string Description,
    string[] AttachmentUrls, Guid? AssignedAdminId,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
