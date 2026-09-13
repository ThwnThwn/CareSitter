using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Domain;

/// <summary>
/// Aggregate root cho 1 ticket ho tro. Map sang bang support.support_tickets.
/// Co created_at + updated_at (trg_ticket_updated).
/// </summary>
public sealed class SupportTicket : AggregateRoot
{
    private SupportTicket() { } // EF

    private SupportTicket(
        Guid id,
        Guid userId,
        Guid? bookingId,
        string type,
        string priority,
        string title,
        string description,
        string? attachmentUrls) : base(id)
    {
        UserId = userId;
        BookingId = bookingId;
        Type = type;
        Priority = priority;
        Title = title;
        Description = description;
        AttachmentUrls = attachmentUrls;
        Status = "NEW";
    }

    public Guid UserId { get; private set; }
    public Guid? BookingId { get; private set; }

    /// <summary>Allowed values: COMPLAINT, SOS, PAYMENT, KYC, CHECKOUT_REVIEW, GENERAL.</summary>
    public string Type { get; private set; } = "GENERAL";

    /// <summary>Allowed values: NEW, IN_PROGRESS, RESOLVED, CLOSED.</summary>
    public string Status { get; private set; } = "NEW";

    /// <summary>Allowed values: LOW, MEDIUM, HIGH, CRITICAL.</summary>
    public string Priority { get; private set; } = "MEDIUM";
    public string Title { get; private set; } = null!;
    public string Description { get; private set; } = null!;
    public string? AttachmentUrls { get; private set; }

    public Guid? AssignedAdminId { get; private set; }

    public static Result<SupportTicket> Create(
        Guid userId,
        string type,
        string priority = "MEDIUM",
        Guid? bookingId = null,
        string? title = null,
        string? description = null,
        string? attachmentUrls = null)
    {
        if (userId == Guid.Empty)
            return Error.Validation("ticket.user", "user_id khong duoc rong.");
        if (string.IsNullOrWhiteSpace(type))
            return Error.Validation("ticket.type", "type khong duoc rong.");
        if (string.IsNullOrWhiteSpace(priority))
            return Error.Validation("ticket.priority", "priority khong duoc rong.");
        var normalizedType = type.Trim().ToUpperInvariant();
        var normalizedPriority = priority.Trim().ToUpperInvariant();
        if (normalizedType is not ("COMPLAINT" or "SOS" or "PAYMENT" or "KYC" or "CHECKOUT_REVIEW" or "GENERAL"))
            return Error.Validation("ticket.type", "type khong hop le.");
        if (normalizedPriority is not ("LOW" or "MEDIUM" or "HIGH" or "CRITICAL"))
            return Error.Validation("ticket.priority", "priority khong hop le.");
        var normalizedTitle = title?.Trim() ?? string.Empty;
        var normalizedDescription = description?.Trim() ?? string.Empty;
        if (normalizedTitle.Length is < 3 or > 255)
            return Error.Validation("ticket.title", "Tieu de phai tu 3 den 255 ky tu.");
        if (normalizedDescription.Length is < 10 or > 5000)
            return Error.Validation("ticket.description", "Mo ta phai tu 10 den 5000 ky tu.");

        return new SupportTicket(Guid.NewGuid(), userId, bookingId,
            normalizedType, normalizedPriority, normalizedTitle, normalizedDescription, attachmentUrls);
    }

    public Result AssignAdmin(Guid adminId)
    {
        if (adminId == Guid.Empty)
            return Error.Validation("ticket.admin", "admin_id khong duoc rong.");
        AssignedAdminId = adminId;
        if (Status == "NEW") Status = "IN_PROGRESS";
        return Result.Success();
    }

    public Result UpdateStatus(string newStatus)
    {
        if (string.IsNullOrWhiteSpace(newStatus))
            return Error.Validation("ticket.status", "status khong duoc rong.");

        var allowed = Status switch
        {
            "NEW" => new[] { "IN_PROGRESS", "CLOSED" },
            "IN_PROGRESS" => new[] { "RESOLVED", "CLOSED" },
            "RESOLVED" => new[] { "CLOSED" },
            _ => Array.Empty<string>()
        };

        if (!allowed.Contains(newStatus))
            return Error.Conflict("ticket.status", $"Khong the chuyen {Status} -> {newStatus}.");

        Status = newStatus;
        return Result.Success();
    }
}
