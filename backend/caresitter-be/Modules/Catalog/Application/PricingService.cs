using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class PricingService(CatalogDbContext db) : IPricingService
{
    public async Task<Result<PriceQuote>> QuoteAsync(Guid serviceTypeId, DateTimeOffset start,
        DateTimeOffset end, CancellationToken ct = default)
    {
        if (end <= start)
            return Error.Validation("pricing.window", "Khoang thoi gian khong hop le.");

        if (!await db.ServiceTypes.AsNoTracking().AnyAsync(x => x.Id == serviceTypeId && x.IsActive, ct))
            return Error.NotFound("pricing.service", "Dich vu khong ton tai hoac da ngung hoat dong.");

        var now = DateTimeOffset.UtcNow;
        var rule = await db.PricingRules.AsNoTracking()
            .Where(x => x.ServiceTypeId == serviceTypeId && x.IsActive &&
                x.EffectiveFrom <= now && (x.EffectiveTo == null || x.EffectiveTo > now))
            .OrderByDescending(x => x.EffectiveFrom).FirstOrDefaultAsync(ct);
        if (rule is null)
            return Error.NotFound("pricing.rule", "Chua co bang gia hieu luc cho dich vu.");

        var hours = (decimal)(end - start).TotalHours;
        var multiplier = start.Hour >= 22 || start.Hour < 6 ? rule.NightMultiplier : 1m;
        var escrow = (long)Math.Round(hours * rule.BaseHourlyPrice * multiplier);
        var fee = (long)Math.Round(escrow * rule.PlatformFeePercent / 100m);
        var snapshot = JsonSerializer.Serialize(new
        {
            ruleId = rule.Id,
            rule.BaseHourlyPrice,
            hours,
            multiplier,
            rule.PlatformFeePercent
        });
        return new PriceQuote(escrow, fee, escrow - fee, rule.DisputeWindowHours, snapshot);
    }
}
