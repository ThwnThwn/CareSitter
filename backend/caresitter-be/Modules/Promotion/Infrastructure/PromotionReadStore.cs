using System.Text.Json;
using CareSitter.Modules.Promotion.Application;
using CareSitter.Modules.Promotion.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Promotion.Infrastructure;

internal sealed class PromotionReadStore(PromotionDbContext db) : IPromotionReadStore
{
    public async Task<IReadOnlyList<PromotionResponse>> ListActiveAsync(
        DateTimeOffset now, CancellationToken ct)
    {
        var items = await db.Promotions.AsNoTracking()
            .Include(x => x.ServiceScopes)
            .Where(x => x.IsActive && x.StartsAt <= now && x.EndsAt >= now)
            .OrderByDescending(x => x.IsFeatured)
            .ThenByDescending(x => x.Priority)
            .ThenBy(x => x.EndsAt)
            .ToListAsync(ct);
        return items.Select(Map).ToArray();
    }

    public async Task<PromotionResponse?> GetActiveAsync(
        Guid id, DateTimeOffset now, CancellationToken ct)
    {
        var item = await db.Promotions.AsNoTracking()
            .Include(x => x.ServiceScopes)
            .SingleOrDefaultAsync(x => x.Id == id && x.IsActive &&
                x.StartsAt <= now && x.EndsAt >= now, ct);
        return item is null ? null : Map(item);
    }

    private static PromotionResponse Map(Domain.Promotion promotion) => new(
        promotion.Id,
        promotion.Code,
        promotion.Title,
        promotion.Summary,
        promotion.Description,
        promotion.BadgeText,
        promotion.DiscountType == PromotionDiscountType.Percentage
            ? "percentage" : "fixed_amount",
        promotion.DiscountValue,
        promotion.MaxDiscountAmount,
        promotion.MinOrderAmount,
        promotion.StartsAt,
        promotion.EndsAt,
        promotion.FirstPaidBookingOnly,
        promotion.PerCustomerUsageLimit,
        promotion.IsFeatured,
        promotion.ServiceScopes.Select(x => x.ServiceTypeId).ToArray(),
        DeserializeTerms(promotion.TermsJson));

    private static IReadOnlyList<string> DeserializeTerms(string value)
    {
        try
        {
            return JsonSerializer.Deserialize<string[]>(value) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
