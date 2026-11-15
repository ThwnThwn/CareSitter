using System.Text.Json;
using CareSitter.Modules.Support.Domain;

namespace CareSitter.Modules.Support.Application;

internal static class SupportResponseMapper
{
    public static DisputeResponse ToResponse(Dispute dispute) => new(dispute.Id,
        dispute.BookingId, dispute.RaisedByUserId, dispute.Reason, dispute.Description,
        dispute.Status, dispute.Decision, dispute.RefundAmount, dispute.OpenedAt,
        dispute.ResolvedAt);

    public static NotificationResponse ToResponse(Notification notification) => new(
        notification.Id, notification.Type, notification.Title, notification.Body,
        notification.Data, notification.ReadAt, notification.CreatedAt);

    public static ReviewResponse ToResponse(Review review) => new(review.Id,
        review.BookingId, review.CaregiverId, review.CustomerId, review.Rating,
        review.Comment, review.ExperienceTags, review.CreatedAt);

    public static SupportTicketResponse ToResponse(SupportTicket ticket) => new(ticket.Id,
        ticket.UserId, ticket.BookingId, ticket.Type, ticket.Status, ticket.Priority,
        ticket.Title, ticket.Description, DeserializeUrls(ticket.AttachmentUrls),
        ticket.AssignedAdminId, ticket.CreatedAt, ticket.UpdatedAt);

    private static string[] DeserializeUrls(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return Array.Empty<string>();
        try { return JsonSerializer.Deserialize<string[]>(json) ?? Array.Empty<string>(); }
        catch (JsonException) { return Array.Empty<string>(); }
    }
}
