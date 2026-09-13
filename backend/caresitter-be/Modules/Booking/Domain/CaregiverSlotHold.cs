using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Giữ tạm một khung giờ của caregiver trong lúc khách đang thanh toán.
/// Database exclusion constraint mới là lớp bảo vệ cuối khi hai booking chạy đồng thời.
/// </summary>
public sealed class CaregiverSlotHold : Entity
{
    private CaregiverSlotHold() { } // EF

    private CaregiverSlotHold(
        Guid id,
        Guid bookingId,
        Guid caregiverId,
        DateTimeOffset scheduledStart,
        DateTimeOffset scheduledEnd,
        DateTimeOffset expiresAt) : base(id)
    {
        BookingId = bookingId;
        CaregiverId = caregiverId;
        ScheduledStart = scheduledStart;
        ScheduledEnd = scheduledEnd;
        ExpiresAt = expiresAt;
        Status = "HELD";
        CreatedAt = DateTimeOffset.UtcNow;
    }

    public Guid BookingId { get; private set; }
    public Guid CaregiverId { get; private set; }
    public DateTimeOffset ScheduledStart { get; private set; }
    public DateTimeOffset ScheduledEnd { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }
    public string Status { get; private set; } = null!;
    public DateTimeOffset? ReleasedAt { get; private set; }

    /// <summary>Tạo hold ngắn hạn cho caregiver đã được khách chọn.</summary>
    public static Result<CaregiverSlotHold> Create(
        Guid bookingId,
        Guid caregiverId,
        DateTimeOffset scheduledStart,
        DateTimeOffset scheduledEnd,
        DateTimeOffset expiresAt)
    {
        if (bookingId == Guid.Empty || caregiverId == Guid.Empty)
            return Error.Validation("caregiver_slot_hold.identity", "booking_id va caregiver_id khong hop le.");
        if (scheduledEnd <= scheduledStart)
            return Error.Validation("caregiver_slot_hold.schedule", "scheduled_end phai sau scheduled_start.");
        if (expiresAt <= DateTimeOffset.UtcNow)
            return Error.Validation("caregiver_slot_hold.expiry", "expires_at phai nam trong tuong lai.");

        return new CaregiverSlotHold(Guid.NewGuid(), bookingId, caregiverId,
            scheduledStart, scheduledEnd, expiresAt);
    }

    /// <summary>Giải phóng hold khi thanh toán hết hạn, thất bại hoặc booking bị hủy.</summary>
    public void Release()
    {
        if (Status != "HELD") return;
        Status = "RELEASED";
        ReleasedAt = DateTimeOffset.UtcNow;
    }

    /// <summary>Chuyển hold sang committed sau khi booking đã thanh toán thành công.</summary>
    public void Commit()
    {
        if (Status == "HELD") Status = "COMMITTED";
    }

    /// <summary>Gia han hold den het payment deadline va grace period doi soat.</summary>
    public void ExtendUntil(DateTimeOffset expiresAt)
    {
        if (Status == "HELD" && expiresAt > ExpiresAt)
            ExpiresAt = expiresAt;
    }
}
