using CareSitter.Modules.Booking.Domain.Events;
using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;

namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Aggregate root cho 1 don cham soc. Bao ve bat bien: chuyen trang thai hop le,
/// geofence khi check-in, escrow snapshot. Map sang bang bookings.
/// </summary>
public sealed class Booking : AggregateRoot
{
    private Booking() { } // EF

    private Booking(
        Guid id,
        Guid customerId,
        Guid beneficiaryId,
        Guid addressId,
        Guid serviceTypeId,
        DateTimeOffset scheduledStart,
        DateTimeOffset scheduledEnd,
        int geofenceRadiusMeters) : base(id)
    {
        CustomerId = customerId;
        BeneficiaryId = beneficiaryId;
        AddressId = addressId;
        ServiceTypeId = serviceTypeId;
        ScheduledStart = scheduledStart;
        ScheduledEnd = scheduledEnd;
        GeofenceRadiusMeters = geofenceRadiusMeters;
        Status = BookingStatus.Draft;
    }

    public Guid CustomerId { get; private set; }
    public Guid BeneficiaryId { get; private set; }
    public Guid? CaregiverId { get; private set; }
    public Guid AddressId { get; private set; }
    public Guid ServiceTypeId { get; private set; }

    public DateTimeOffset ScheduledStart { get; private set; }
    public DateTimeOffset ScheduledEnd { get; private set; }
    public DateTimeOffset? ActualStart { get; private set; }
    public DateTimeOffset? ActualEnd { get; private set; }

    public BookingStatus Status { get; private set; }

    public long EscrowAmount { get; private set; }
    public long PlatformFeeAmount { get; private set; }
    public long CaregiverEarningAmount { get; private set; }
    public string? PriceSnapshot { get; private set; }
    public int GeofenceRadiusMeters { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public Guid? CancelledByUserId { get; private set; }
    public string? CancelledByRole { get; private set; }
    public string? CancelReason { get; private set; }

    public static Result<Booking> Create(
        Guid customerId,
        Guid beneficiaryId,
        Guid addressId,
        Guid serviceTypeId,
        DateTimeOffset scheduledStart,
        DateTimeOffset scheduledEnd,
        int geofenceRadiusMeters = 50)
    {
        if (scheduledEnd <= scheduledStart)
            return Error.Validation("booking.schedule", "scheduled_end phai sau scheduled_start.");

        var booking = new Booking(Guid.NewGuid(), customerId, beneficiaryId, addressId, serviceTypeId,
            scheduledStart, scheduledEnd, geofenceRadiusMeters);
        return booking;
    }

    public Result ApplyPricing(long escrow, long platformFee, long caregiverEarning, string? snapshot = null)
    {
        if (escrow < 0 || platformFee < 0 || caregiverEarning < 0)
            return Error.Validation("booking.pricing", "So tien khong duoc am.");

        EscrowAmount = escrow;
        PlatformFeeAmount = platformFee;
        CaregiverEarningAmount = caregiverEarning;
        PriceSnapshot = snapshot;
        return Result.Success();
    }

    public Result SelectCaregiver(Guid caregiverId)
    {
        if (caregiverId == Guid.Empty || Status is not (BookingStatus.Draft or BookingStatus.PendingPayment or BookingStatus.Confirmed))
            return Error.Conflict("booking.select_caregiver", "Khong the chon caregiver o trang thai hien tai.");
        CaregiverId = caregiverId;
        return Result.Success();
    }

    public Result Reschedule(DateTimeOffset start, DateTimeOffset end)
    {
        if (end <= start)
            return Error.Validation("booking.schedule", "Thoi gian ket thuc phai sau thoi gian bat dau.");
        if (Status is not (BookingStatus.Draft or BookingStatus.PendingPayment or BookingStatus.Confirmed))
            return Error.Conflict("booking.reschedule", "Khong the doi lich o trang thai hien tai.");
        ScheduledStart = start;
        ScheduledEnd = end;
        return Result.Success();
    }

    public Result AssignCaregiver(Guid caregiverId)
    {
        if (Status is not (BookingStatus.Confirmed or BookingStatus.Crisis))
            return Error.Conflict("booking.assign", "Chi gan CSV khi don da CONFIRMED hoac dang CRISIS.");

        CaregiverId = caregiverId;
        return TransitionTo(BookingStatus.CaregiverAccepted);
    }

    /// <summary>Check-in: chi hop le khi GPS trong ban kinh geofence (tru khi admin override).</summary>
    public Result CheckIn(GeoPoint caregiverLocation, GeoPoint addressLocation, bool adminOverride = false)
    {
        if (Status != BookingStatus.CaregiverEnRoute)
            return Error.Conflict("booking.checkin", "Chi check-in khi CSV dang EN_ROUTE.");

        double distance = caregiverLocation.DistanceMetersTo(addressLocation);
        if (!adminOverride && distance > GeofenceRadiusMeters)
            return Error.Validation("booking.geofence",
                $"Ngoai ban kinh cho phep ({distance:F0}m > {GeofenceRadiusMeters}m).");

        ActualStart = DateTimeOffset.UtcNow;
        var result = TransitionTo(BookingStatus.InProgress);
        if (result.IsSuccess)
            Raise(new BookingCheckedIn(Id, CaregiverId!.Value, distance));
        return result;
    }

    public Result Complete()
    {
        var result = TransitionTo(BookingStatus.Completed);
        if (result.IsFailure)
            return result;

        ActualEnd = DateTimeOffset.UtcNow;
        Raise(new BookingCompletedDomainEvent(Id, CaregiverId!.Value, EscrowAmount));
        return result;
    }

    public Result RequestManualCheckout() => TransitionTo(BookingStatus.CheckoutPendingReview);

    public Result RaiseSos(Guid? raisedByUserId)
    {
        var result = TransitionTo(BookingStatus.Crisis);
        if (result.IsSuccess)
            Raise(new BookingSosRaised(Id, raisedByUserId));
        return result;
    }

    public Result StartEnRoute() => TransitionTo(BookingStatus.CaregiverEnRoute);
    public Result ConfirmPayment() => TransitionTo(BookingStatus.Confirmed);
    public Result Cancel(Guid userId, string role, string? reason, DateTimeOffset cancelledAt)
    {
        var result = TransitionTo(BookingStatus.Cancelled);
        if (result.IsFailure)
            return result;
        CancelledAt = cancelledAt;
        CancelledByUserId = userId;
        CancelledByRole = role;
        CancelReason = reason?.Trim();
        return Result.Success();
    }

    public Result TransitionTo(BookingStatus next)
    {
        if (!BookingStateMachine.CanTransition(Status, next))
            return Error.Conflict("booking.transition", $"Khong the chuyen {Status} -> {next}.");

        var from = Status;
        Status = next;
        Raise(new BookingStatusChanged(Id, from, next));
        return Result.Success();
    }
}
