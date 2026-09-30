using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>
/// Boundary owned by Promotion and consumed by Booking. Monetary values are VND.
/// Booking supplies the authoritative catalog quote; Promotion never trusts a client price.
/// </summary>
public interface IPromotionService
{
    Task<Result<PromotionPriceQuote>> PreviewAsync(
        PromotionPriceRequest request, CancellationToken ct = default);

    Task<Result<PromotionPriceQuote>> ReserveAsync(
        PromotionReservationRequest request, CancellationToken ct = default);

    Task<Result> RedeemAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default);

    Task<Result> ReleaseAsync(Guid bookingId, Guid customerId, string reason,
        CancellationToken ct = default);
}

public sealed record PromotionPriceRequest(
    string Code,
    Guid CustomerId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    long GrossAmount,
    Guid? BookingId = null);

public sealed record PromotionReservationRequest(
    string Code,
    Guid CustomerId,
    Guid BookingId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    DateTimeOffset ExpiresAt,
    long GrossAmount);

public sealed record PromotionPriceQuote(
    Guid PromotionId,
    string Code,
    string Title,
    long GrossAmount,
    long DiscountAmount,
    long CustomerPayableAmount,
    long PlatformSubsidyAmount);

/// <summary>Booking-owned read boundary used only for promotion eligibility.</summary>
public interface IPromotionBookingLookup
{
    Task<bool> HasPaidBookingAsync(Guid customerId, CancellationToken ct = default);
}
