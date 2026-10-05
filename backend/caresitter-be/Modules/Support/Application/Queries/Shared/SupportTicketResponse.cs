namespace CareSitter.Modules.Support.Application;

public sealed record SupportTicketResponse(Guid Id, Guid UserId, Guid? BookingId,
    string Type, string Status, string Priority, string Title, string Description,
    string[] AttachmentUrls, Guid? AssignedAdminId,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);
