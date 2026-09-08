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
        string priority) : base(id)
    {
        UserId = userId;
        BookingId = bookingId;
        Type = type;
        Priority = priority;
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

    public Guid? AssignedAdminId { get; private set; }

    public static Result<SupportTicket> Create(
        Guid userId,
        string type,
        string priority = "MEDIUM",
        Guid? bookingId = null)
    {
        if (userId == Guid.Empty)
            return Error.Validation("ticket.user", "user_id khong duoc rong.");
        if (string.IsNullOrWhiteSpace(type))
            return Error.Validation("ticket.type", "type khong duoc rong.");
        if (string.IsNullOrWhiteSpace(priority))
            return Error.Validation("ticket.priority", "priority khong duoc rong.");

        return new SupportTicket(Guid.NewGuid(), userId, bookingId, type, priority);
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
