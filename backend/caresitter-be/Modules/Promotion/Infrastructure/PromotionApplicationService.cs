using System.Data;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Promotion.Infrastructure;

internal sealed class PromotionApplicationService(
    PromotionDbContext db,
    IPromotionBookingLookup bookingLookup,
    IClock clock) : IPromotionService
{
    public async Task<Result<PromotionPriceQuote>> PreviewAsync(
        PromotionPriceRequest request, CancellationToken ct = default)
    {
        var now = clock.UtcNow;
        var promotion = await db.Promotions.AsNoTracking()
            .Include(x => x.ServiceScopes)
            .SingleOrDefaultAsync(x => x.Code == NormalizeCode(request.Code), ct);
        if (promotion is null) return PromotionErrors.NotFound();

        var eligibility = await EnsureEligibleAsync(promotion, request.CustomerId,
            request.ServiceTypeId, request.GrossAmount, now, request.BookingId, ct);
        if (eligibility.IsFailure) return eligibility.Error;

        return ToQuote(promotion, request.GrossAmount, eligibility.Value);
    }

    public async Task<Result<PromotionPriceQuote>> ReserveAsync(
        PromotionReservationRequest request, CancellationToken ct = default)
    {
        var now = clock.UtcNow;
        if (request.ExpiresAt <= now)
            return PromotionErrors.InvalidReservation();

        await using var tx = await db.Database.BeginTransactionAsync(
            IsolationLevel.ReadCommitted, ct);
        var code = NormalizeCode(request.Code);
        var promotion = await db.Promotions
            .FromSqlInterpolated($"SELECT * FROM promotion.promotions WHERE code = {code} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (promotion is null) return PromotionErrors.NotFound();
        await db.Entry(promotion).Collection(x => x.ServiceScopes).LoadAsync(ct);

        var eligibility = await EnsureEligibleAsync(promotion, request.CustomerId,
            request.ServiceTypeId, request.GrossAmount, now, request.BookingId, ct);
        if (eligibility.IsFailure) return eligibility.Error;

        var existing = await db.PromotionRedemptions.SingleOrDefaultAsync(
            x => x.BookingId == request.BookingId, ct);
        if (existing is not null)
        {
            if (existing.PromotionId != promotion.Id || existing.CustomerId != request.CustomerId)
                return PromotionErrors.InvalidReservation();
            var refreshed = existing.Refresh(eligibility.Value, request.ExpiresAt, now);
            if (refreshed.IsFailure) return refreshed.Error;
        }
        else
        {
            var reservation = PromotionRedemption.Reserve(promotion.Id,
                request.CustomerId, request.BookingId, eligibility.Value, now,
                request.ExpiresAt);
            if (reservation.IsFailure) return reservation.Error;
            db.PromotionRedemptions.Add(reservation.Value);
        }

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToQuote(promotion, request.GrossAmount, eligibility.Value);
    }

    public async Task<Result> RedeemAsync(Guid bookingId, Guid customerId,
        CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var redemption = await db.PromotionRedemptions
            .FromSqlInterpolated($"SELECT * FROM promotion.promotion_redemptions WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (redemption is null)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (redemption.CustomerId != customerId)
            return PromotionErrors.InvalidReservation();

        var result = redemption.Redeem(clock.UtcNow);
        if (result.IsFailure) return result;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Result.Success();
    }

    public async Task<Result> ReleaseAsync(Guid bookingId, Guid customerId,
        string reason, CancellationToken ct = default)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var redemption = await db.PromotionRedemptions
            .FromSqlInterpolated($"SELECT * FROM promotion.promotion_redemptions WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (redemption is null)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }
        if (redemption.CustomerId != customerId)
            return PromotionErrors.InvalidReservation();
        if (redemption.Status == PromotionRedemptionStatus.Redeemed)
        {
            await tx.CommitAsync(ct);
            return Result.Success();
        }

        var result = redemption.Release(clock.UtcNow, reason);
        if (result.IsFailure) return result;
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return Result.Success();
    }

    private async Task<Result<long>> EnsureEligibleAsync(Domain.Promotion promotion,
        Guid customerId, Guid serviceTypeId, long grossAmount, DateTimeOffset now,
        Guid? bookingId, CancellationToken ct)
    {
        if (!promotion.IsAvailableAt(now)) return PromotionErrors.NotActive();
        if (!promotion.AppliesToService(serviceTypeId))
            return PromotionErrors.ServiceNotEligible();
        if (promotion.FirstPaidBookingOnly &&
            await bookingLookup.HasPaidBookingAsync(customerId, ct))
            return PromotionErrors.FirstBookingOnly();

        var activeUsages = db.PromotionRedemptions.AsNoTracking().Where(x =>
            x.PromotionId == promotion.Id &&
            (x.Status == PromotionRedemptionStatus.Redeemed ||
             (x.Status == PromotionRedemptionStatus.Reserved && x.ExpiresAt >= now)));
        if (bookingId is { } excludedBookingId)
            activeUsages = activeUsages.Where(x => x.BookingId != excludedBookingId);

        if (promotion.TotalUsageLimit is { } totalLimit &&
            await activeUsages.CountAsync(ct) >= totalLimit)
            return PromotionErrors.UsageLimitReached();
        if (await activeUsages.CountAsync(x => x.CustomerId == customerId, ct) >=
            promotion.PerCustomerUsageLimit)
            return PromotionErrors.CustomerUsageLimitReached();

        return promotion.CalculateDiscount(grossAmount);
    }

    private static PromotionPriceQuote ToQuote(Domain.Promotion promotion,
        long grossAmount, long discountAmount) => new(
            promotion.Id,
            promotion.Code,
            promotion.Title,
            grossAmount,
            discountAmount,
            grossAmount - discountAmount,
            discountAmount);

    private static string NormalizeCode(string code) => code.Trim().ToUpperInvariant();
}
