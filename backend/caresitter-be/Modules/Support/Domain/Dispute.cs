using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Support.Domain;

/// <summary>
/// Aggregate root cho 1 tranh chap (dispute) gan voi 1 booking. Map sang bang support.disputes.
/// Khong co created_at/updated_at — thoi diem mien nghiep vu la opened_at/resolved_at.
/// </summary>
public sealed class Dispute : AggregateRoot
{
    private Dispute() { } // EF

    private Dispute(
        Guid id,
        Guid bookingId,
        Guid raisedByUserId,
        string? reason,
        string? description) : base(id)
    {
        BookingId = bookingId;
        RaisedByUserId = raisedByUserId;
        Reason = reason;
        Description = description;
        Status = "OPEN";
        OpenedAt = DateTimeOffset.UtcNow;
    }

    public Guid BookingId { get; private set; }
    public Guid RaisedByUserId { get; private set; }

    public string? Reason { get; private set; }
    public string? Description { get; private set; }

    /// <summary>Allowed values: OPEN, INVESTIGATING, RESOLVED, CANCELLED.</summary>
    public string Status { get; private set; } = "OPEN";

    /// <summary>jsonb — gom dispute_evidence.</summary>
    public string? Evidence { get; private set; }

    /// <summary>Allowed values: CUSTOMER_WINS, CAREGIVER_WINS, PARTIAL_REFUND.</summary>
    public string? Decision { get; private set; }

    public long? RefundAmount { get; private set; }
    public long? CaregiverPenaltyAmount { get; private set; }
    public Guid? DecidedByAdminId { get; private set; }

    public DateTimeOffset OpenedAt { get; private set; }
    public DateTimeOffset? ResolvedAt { get; private set; }

    public static Result<Dispute> Create(
        Guid bookingId,
        Guid raisedByUserId,
        string? reason = null,
        string? description = null)
    {
        if (bookingId == Guid.Empty)
            return Error.Validation("dispute.booking", "booking_id không được rỗng.");
        if (raisedByUserId == Guid.Empty)
            return Error.Validation("dispute.raisedBy", "raised_by_user_id không được rỗng.");

        return new Dispute(Guid.NewGuid(), bookingId, raisedByUserId, reason, description);
    }

    public Result Investigate()
    {
        if (Status != "OPEN")
            return Error.Conflict("dispute.status", $"không thể chuyen {Status} -> INVESTIGATING.");
        Status = "INVESTIGATING";
        return Result.Success();
    }

    public Result Resolve(Guid adminId, string decision, long? refundAmount = null, long? caregiverPenalty = null)
    {
        if (Status is not ("OPEN" or "INVESTIGATING"))
            return Error.Conflict("dispute.status", $"không thể chuyen {Status} -> RESOLVED.");
        if (decision is not ("CUSTOMER_WINS" or "CAREGIVER_WINS" or "PARTIAL_REFUND"))
            return Error.Validation("dispute.decision", "Decision phai la CUSTOMER_WINS, CAREGIVER_WINS hoac PARTIAL_REFUND.");
        if (refundAmount is < 0)
            return Error.Validation("dispute.refund_amount", "Số tiền hoàn không được âm.");
        if (caregiverPenalty is < 0)
            return Error.Validation("dispute.caregiver_penalty", "Mức phạt không được âm.");

        Status = "RESOLVED";
        Decision = decision;
        DecidedByAdminId = adminId;
        RefundAmount = refundAmount;
        CaregiverPenaltyAmount = caregiverPenalty;
        ResolvedAt = DateTimeOffset.UtcNow;
        return Result.Success();
    }

    public Result Cancel()
    {
        if (Status is not ("OPEN" or "INVESTIGATING"))
            return Error.Conflict("dispute.status", $"không thể chuyen {Status} -> CANCELLED.");
        Status = "CANCELLED";
        ResolvedAt = DateTimeOffset.UtcNow;
        return Result.Success();
    }
}
