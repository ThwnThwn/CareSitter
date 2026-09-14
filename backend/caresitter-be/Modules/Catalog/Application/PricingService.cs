using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class PricingService(CatalogDbContext db, IConfiguration configuration) : IPricingService
{
    /// <summary>Múi giờ nghiệp vụ của lịch chăm sóc tại Việt Nam.</summary>
    private static TimeZoneInfo VietnamTimeZone =>
        TimeZoneInfo.FindSystemTimeZoneById(
            OperatingSystem.IsWindows() ? "SE Asia Standard Time" : "Asia/Ho_Chi_Minh");

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
        var localStart = TimeZoneInfo.ConvertTime(start, VietnamTimeZone);
        var enableTimeMultipliers = configuration.GetValue<bool>("Pricing:EnableTimeMultipliers");
        var nightMultiplier = enableTimeMultipliers && (localStart.Hour >= 22 || localStart.Hour < 6)
            ? rule.NightMultiplier
            : 1m;
        var holidayMultiplier = enableTimeMultipliers
            ? ResolveHolidayMultiplier(rule.Holidays, localStart.Date)
            : 1m;
        var multiplier = nightMultiplier * holidayMultiplier;
        var escrow = (long)Math.Round(hours * rule.BaseHourlyPrice * multiplier);
        var fee = (long)Math.Round(escrow * rule.PlatformFeePercent / 100m);
        var snapshot = JsonSerializer.Serialize(new
        {
            ruleId = rule.Id,
            rule.BaseHourlyPrice,
            hours,
            localStart = localStart.ToString("yyyy-MM-dd HH:mm zzz"),
            pricingMode = enableTimeMultipliers ? "TIME_MULTIPLIERS" : "BASE_ONLY",
            nightMultiplier,
            holidayMultiplier,
            multiplier,
            rule.PlatformFeePercent
        });
        return new PriceQuote(escrow, fee, escrow - fee, rule.DisputeWindowHours, snapshot);
    }

    /// <summary>Đọc hệ số ngày lễ theo ngày địa phương từ cấu hình JSON của pricing rule.</summary>
    private static decimal ResolveHolidayMultiplier(string? holidays, DateTime localDate)
    {
        if (string.IsNullOrWhiteSpace(holidays)) return 1m;

        try
        {
            using var document = JsonDocument.Parse(holidays);
            if (document.RootElement.ValueKind != JsonValueKind.Array) return 1m;

            foreach (var item in document.RootElement.EnumerateArray())
            {
                if (!item.TryGetProperty("date", out var dateElement) ||
                    !DateTime.TryParse(dateElement.GetString(), out var date) ||
                    date.Date != localDate.Date)
                    continue;

                if (item.TryGetProperty("multiplier", out var multiplierElement) &&
                    multiplierElement.TryGetDecimal(out var multiplier) && multiplier > 0m)
                    return multiplier;
            }
        }
        catch (JsonException)
        {
            // Cấu hình ngày lễ lỗi không được làm hỏng việc báo giá; dùng giá thường.
        }

        return 1m;
    }
}
