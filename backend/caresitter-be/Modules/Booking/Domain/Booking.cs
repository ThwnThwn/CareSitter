using CareSitter.Modules.Booking.Domain.Events;
using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;

namespace CareSitter.Modules.Booking.Domain;

/// <summary>
/// Aggregate root cho một đơn chăm sóc. Bảo vệ bất biến: chuyển trạng thái hợp lệ,
/// geofence khi check-in, escrow snapshot. Map sang bảng bookings.
/// </summary>
public sealed class Booking : AggregateRoot
{
    public const int CheckInRadiusMeters = 50;
    public static readonly TimeSpan CheckInEarlyWindow = TimeSpan.FromMinutes(30);

    private Booking() { } // EF

    private Booking(
        Guid id,
        Guid customerId,
        Guid beneficiaryId,
        Guid addressId,
        Guid serviceTypeId,
        DateTimeOffset scheduledStart,
        DateTimeOffset scheduledEnd,
        DateTimeOffset paymentDeadline,
        int geofenceRadiusMeters,
        string? requiredSkills) : base(id)
    {
        CustomerId = customerId;
        BeneficiaryId = beneficiaryId;
        AddressId = addressId;
        ServiceTypeId = serviceTypeId;
        ScheduledStart = scheduledStart;
        ScheduledEnd = scheduledEnd;
        PaymentDeadline = paymentDeadline;
        GeofenceRadiusMeters = geofenceRadiusMeters;
        RequiredSkills = requiredSkills;
        Status = BookingStatus.Draft;
    }

    public Guid CustomerId { get; private set; }
    public Guid BeneficiaryId { get; private set; }
    public Guid? CaregiverId { get; private set; }
    public Guid AddressId { get; private set; }
    public Guid ServiceTypeId { get; private set; }

    public DateTimeOffset ScheduledStart { get; private set; }
    public DateTimeOffset ScheduledEnd { get; private set; }
    public DateTimeOffset PaymentDeadline { get; private set; }
    public DateTimeOffset? ActualStart { get; private set; }
    public DateTimeOffset? ActualEnd { get; private set; }
    public DateTimeOffset? CheckoutPendingReviewAt { get; private set; }
    public BookingCheckoutSource? CheckoutSource { get; private set; }
    public bool NeedsReview { get; private set; }
    /// <summary>Snapshot quyền thêm công việc phát sinh của gói tại thời điểm thanh toán.</summary>
    public bool AllowAdHocTasks { get; private set; }
    public string? RequiredSkills { get; private set; }

    public BookingStatus Status { get; private set; }

    /// <summary>
    /// Tăng mỗi khi booking bị mutation. Client dùng để bỏ qua update cũ / đến đảo thứ tự.
    /// Tương ứng cột sync_version trong bảng bookings.
    /// </summary>
    public long SyncVersion { get; private set; } = 1;

    /// <summary>Gọi trong service layer trước khi ghi BookingSyncEvent.</summary>
    internal void IncrementSyncVersion() => SyncVersion++;

    public long EscrowAmount { get; private set; }
    public long PlatformFeeAmount { get; private set; }
    public long CaregiverEarningAmount { get; private set; }
    public long CustomerPayableAmount { get; private set; }
    public long PromotionDiscountAmount { get; private set; }
    public long PromotionSubsidyAmount { get; private set; }
    public Guid? PromotionId { get; private set; }
    public string? PromotionCode { get; private set; }
    public string? PriceSnapshot { get; private set; }
    public int DisputeWindowHours { get; private set; } = 48;
    public DateTimeOffset? SettlementReleasedAt { get; private set; }
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
        DateTimeOffset? paymentDeadline = null,
        int geofenceRadiusMeters = 50,
        string? requiredSkills = null)
    {
        if (scheduledEnd <= scheduledStart)
            return Error.Validation("booking.schedule", "scheduled_end phải sau scheduled_start.");

        var booking = new Booking(Guid.NewGuid(), customerId, beneficiaryId, addressId, serviceTypeId,
            scheduledStart, scheduledEnd, paymentDeadline ?? DateTimeOffset.UtcNow.AddMinutes(15),
            geofenceRadiusMeters, requiredSkills);
        return booking;
    }

    public Result ApplyPricing(long escrow, long platformFee, long caregiverEarning,
        string? snapshot = null, int disputeWindowHours = 48)
    {
        if (escrow < 0 || platformFee < 0 || caregiverEarning < 0)
            return Error.Validation("booking.pricing", "Số tiền không được âm.");
        if (disputeWindowHours is < 1 or > 720)
            return Error.Validation("booking.dispute_window",
                "Thời hạn khiếu nại phải từ 1 đến 720 giờ.");

        EscrowAmount = escrow;
        PlatformFeeAmount = platformFee;
        CaregiverEarningAmount = caregiverEarning;
        if (PromotionId is null)
        {
            CustomerPayableAmount = escrow;
            PromotionDiscountAmount = 0;
            PromotionSubsidyAmount = 0;
        }
        else
        {
            PromotionDiscountAmount = Math.Min(PromotionDiscountAmount, escrow);
            PromotionSubsidyAmount = PromotionDiscountAmount;
            CustomerPayableAmount = escrow - PromotionDiscountAmount;
        }
        PriceSnapshot = snapshot;
        DisputeWindowHours = disputeWindowHours;
        return Result.Success();
    }

    public Result ApplyPromotion(Guid promotionId, string code, long grossAmount,
        long discountAmount, long customerPayableAmount, long platformSubsidyAmount)
    {
        if (promotionId == Guid.Empty || string.IsNullOrWhiteSpace(code))
            return Error.Validation("booking.promotion", "Thông tin ưu đãi không hợp lệ.");
        if (grossAmount != EscrowAmount || discountAmount <= 0 ||
            customerPayableAmount < 0 || platformSubsidyAmount < 0 ||
            customerPayableAmount + discountAmount != grossAmount ||
            platformSubsidyAmount != discountAmount)
            return Error.Validation("booking.promotion_pricing", "Giá ưu đãi không hợp lệ.");

        PromotionId = promotionId;
        PromotionCode = code.Trim().ToUpperInvariant();
        PromotionDiscountAmount = discountAmount;
        PromotionSubsidyAmount = platformSubsidyAmount;
        CustomerPayableAmount = customerPayableAmount;
        return Result.Success();
    }

    public Result MarkSettlementReleased(DateTimeOffset releasedAt)
    {
        if (Status != BookingStatus.Completed)
            return Error.Conflict("booking.settlement.invalid_state",
                "Chỉ có thể giải ngân booking đã hoàn thành.");
        SettlementReleasedAt ??= releasedAt;
        return Result.Success();
    }

    public Result SelectCaregiver(Guid caregiverId)
    {
        if (caregiverId == Guid.Empty || Status is not (BookingStatus.Draft or BookingStatus.PendingPayment or BookingStatus.Confirmed))
            return Error.Conflict("booking.select_caregiver", "Không thể chọn caregiver ở trạng thái hiện tại.");
        CaregiverId = caregiverId;
        return Result.Success();
    }

    public Result Reschedule(DateTimeOffset start, DateTimeOffset end)
    {
        if (end <= start)
            return Error.Validation("booking.schedule", "Thời gian kết thúc phải sau thời gian bắt đầu.");
        if (Status is not (BookingStatus.Draft or BookingStatus.PendingPayment or BookingStatus.Confirmed))
            return Error.Conflict("booking.reschedule", "Không thể dời lịch ở trạng thái hiện tại.");
        ScheduledStart = start;
        ScheduledEnd = end;
        return Result.Success();
    }

    public Result AssignCaregiver(Guid caregiverId)
    {
        if (Status is not (BookingStatus.Confirmed or BookingStatus.Crisis))
            return Error.Conflict("booking.assign", "Chỉ gán caregiver khi đơn đã CONFIRMED hoặc đang CRISIS.");

        CaregiverId = caregiverId;
        return TransitionTo(BookingStatus.CaregiverAccepted);
    }

    /// <summary>
    /// Check-in chỉ hợp lệ từ 30 phút trước giờ bắt đầu ca, và khi GPS nằm trong geofence.
    /// <paramref name="checkedInAt"/> phải do server cấp; không dùng timestamp từ client.
    /// </summary>
    public Result CheckIn(
        GeoPoint caregiverLocation,
        GeoPoint addressLocation,
        bool adminOverride = false,
        DateTimeOffset? checkedInAt = null,
        TimeSpan? earlyWindow = null,
        int? checkInRadiusMeters = null)
    {
        if (Status != BookingStatus.CaregiverEnRoute)
            return Error.Conflict("booking.checkin", "Chỉ check-in khi caregiver đang EN_ROUTE.");

        var serverNow = checkedInAt ?? DateTimeOffset.UtcNow;
        var allowedEarlyWindow = earlyWindow ?? CheckInEarlyWindow;
        var earliestCheckIn = ScheduledStart - allowedEarlyWindow;
        if (serverNow < earliestCheckIn)
            return Error.Validation("booking.checkin_too_early",
                $"Chỉ được check-in từ {earliestCheckIn:HH:mm dd/MM/yyyy}, tối đa 30 phút trước giờ bắt đầu ca.");

        double distance = caregiverLocation.DistanceMetersTo(addressLocation);
        int allowedRadiusMeters = checkInRadiusMeters ?? CheckInRadiusMeters;
        if (!adminOverride && distance > allowedRadiusMeters)
            return Error.Validation("booking.geofence",
                $"Ngoài bán kính cho phép ({distance:F0}m > {allowedRadiusMeters}m).");

        ActualStart = serverNow;
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

    public Result RequestManualCheckout() =>
        RequestCheckout(BookingCheckoutSource.CaregiverRequested, DateTimeOffset.UtcNow);

    public void MarkNeedsReview() => NeedsReview = true;
    public void SnapshotChecklistPolicy(bool allowAdHocTasks) => AllowAdHocTasks = allowAdHocTasks;

    public Result RequestSystemTimeoutCheckout(DateTimeOffset requestedAt) =>
        RequestCheckout(BookingCheckoutSource.SystemTimeout, requestedAt);

    public Result RequestAdminOverrideCheckout(DateTimeOffset requestedAt) =>
        RequestCheckout(BookingCheckoutSource.AdminOverride, requestedAt);

    private Result RequestCheckout(BookingCheckoutSource source, DateTimeOffset requestedAt)
    {
        var result = TransitionTo(BookingStatus.CheckoutPendingReview);
        if (result.IsFailure)
            return result;

        CheckoutPendingReviewAt = requestedAt;
        CheckoutSource = source;
        return Result.Success();
    }

    public Result RaiseSos(Guid? raisedByUserId)
    {
        var result = TransitionTo(BookingStatus.Crisis);
        if (result.IsSuccess)
            Raise(new BookingSosRaised(Id, raisedByUserId));
        return result;
    }

    public Result StartEnRoute() => TransitionTo(BookingStatus.CaregiverEnRoute);
    public Result ConfirmPayment() => TransitionTo(BookingStatus.Confirmed);
    public Result BeginPaymentReconciliation() => TransitionTo(BookingStatus.PaymentReconciliationPending);
    public Result MarkPaymentNeedsManualReview() => TransitionTo(BookingStatus.NeedsManualReview);
    public Result MarkMatchingFailed() => TransitionTo(BookingStatus.MatchingFailed);
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
            return Error.Conflict("booking.transition", $"Không thể chuyển {Status} -> {next}.");

        var from = Status;
        Status = next;
        Raise(new BookingStatusChanged(Id, from, next));
        return Result.Success();
    }
}
