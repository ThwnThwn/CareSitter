using System.Data;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Domain.Policies;
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
            var binding = PromotionEligibilityPolicy.CheckReservationBinding(
                existing, promotion.Id, request.CustomerId);
            if (binding.IsFailure) return binding.Error;
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
        var applicability = PromotionEligibilityPolicy.CheckApplicability(promotion, serviceTypeId, now);
        if (applicability.IsFailure) return applicability.Error;
        var history = PromotionEligibilityPolicy.CheckCustomerHistory(promotion,
            promotion.FirstPaidBookingOnly && await bookingLookup.HasPaidBookingAsync(customerId, ct));
        if (history.IsFailure) return history.Error;

        var activeUsages = db.PromotionRedemptions.AsNoTracking().Where(x =>
            x.PromotionId == promotion.Id &&
            (x.Status == PromotionRedemptionStatus.Redeemed ||
             (x.Status == PromotionRedemptionStatus.Reserved && x.ExpiresAt >= now)));
        if (bookingId is { } excludedBookingId)
            activeUsages = activeUsages.Where(x => x.BookingId != excludedBookingId);

        var totalUsage = promotion.TotalUsageLimit is not null ? await activeUsages.CountAsync(ct) : 0;
        var quota = PromotionEligibilityPolicy.CheckTotalUsage(promotion, totalUsage);
        if (quota.IsFailure) return quota.Error;
        var customerUsage = await activeUsages.CountAsync(x => x.CustomerId == customerId, ct);
        return PromotionEligibilityPolicy.CalculateDiscount(promotion, grossAmount, customerUsage);
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
