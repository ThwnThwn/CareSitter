using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Domain;

public enum PromotionRedemptionStatus
{
    Reserved,
    Redeemed,
    Released
}

public sealed class PromotionRedemption : Entity
{
    private PromotionRedemption() { }

    private PromotionRedemption(Guid id, Guid promotionId, Guid customerId,
        Guid bookingId, long discountAmount, DateTimeOffset reservedAt,
        DateTimeOffset expiresAt) : base(id)
    {
        PromotionId = promotionId;
        CustomerId = customerId;
        BookingId = bookingId;
        DiscountAmount = discountAmount;
        ReservedAt = reservedAt;
        ExpiresAt = expiresAt;
        Status = PromotionRedemptionStatus.Reserved;
    }

    public Guid PromotionId { get; private set; }
    public Guid CustomerId { get; private set; }
    public Guid BookingId { get; private set; }
    public long DiscountAmount { get; private set; }
    public PromotionRedemptionStatus Status { get; private set; }
    public DateTimeOffset ReservedAt { get; private set; }
    public DateTimeOffset ExpiresAt { get; private set; }
    public DateTimeOffset? RedeemedAt { get; private set; }
    public DateTimeOffset? ReleasedAt { get; private set; }
    public string? ReleaseReason { get; private set; }

    public static Result<PromotionRedemption> Reserve(Guid promotionId, Guid customerId,
        Guid bookingId, long discountAmount, DateTimeOffset reservedAt,
        DateTimeOffset expiresAt)
    {
        if (promotionId == Guid.Empty || customerId == Guid.Empty || bookingId == Guid.Empty)
            return PromotionErrors.InvalidReservation();
        if (discountAmount <= 0 || expiresAt <= reservedAt)
            return PromotionErrors.InvalidReservation();

        return new PromotionRedemption(Guid.NewGuid(), promotionId, customerId,
            bookingId, discountAmount, reservedAt, expiresAt);
    }

    public Result Redeem(DateTimeOffset now)
    {
        if (Status == PromotionRedemptionStatus.Redeemed)
            return Result.Success();
        if (Status != PromotionRedemptionStatus.Reserved)
            return PromotionErrors.ReservationExpired();

        Status = PromotionRedemptionStatus.Redeemed;
        RedeemedAt = now;
        UpdatedAt = now;
        return Result.Success();
    }

    public Result Refresh(long discountAmount, DateTimeOffset expiresAt, DateTimeOffset now)
    {
        if (Status != PromotionRedemptionStatus.Reserved)
            return PromotionErrors.AlreadyRedeemed();
        if (discountAmount <= 0 || expiresAt <= now)
            return PromotionErrors.InvalidReservation();

        DiscountAmount = discountAmount;
        ExpiresAt = expiresAt;
        UpdatedAt = now;
        return Result.Success();
    }

    public Result Release(DateTimeOffset now, string reason)
    {
        if (Status == PromotionRedemptionStatus.Released)
            return Result.Success();
        if (Status == PromotionRedemptionStatus.Redeemed)
            return PromotionErrors.AlreadyRedeemed();

        Status = PromotionRedemptionStatus.Released;
        ReleasedAt = now;
        ReleaseReason = string.IsNullOrWhiteSpace(reason) ? "UNSPECIFIED" : reason.Trim();
        UpdatedAt = now;
        return Result.Success();
    }
}
