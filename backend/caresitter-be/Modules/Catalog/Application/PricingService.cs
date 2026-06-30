using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

/// <summary>
/// Implement IPricingService (Contracts) — Catalog so huu logic gia.
/// MVP tinh tam: gia co ban 90k/gio, phi nen tang 15%. Production doc tu pricing_rules.
/// </summary>
internal sealed class PricingService : IPricingService
{
    private const long BaseHourlyPrice = 90_000;
    private const decimal PlatformFeePercent = 0.15m;
    private const int DefaultDisputeWindowHours = 48;

    public Task<Result<PriceQuote>> QuoteAsync(Guid serviceTypeId, DateTimeOffset start, DateTimeOffset end,
        CancellationToken ct = default)
    {
        if (end <= start)
            return Task.FromResult(Result.Failure<PriceQuote>(
                Error.Validation("pricing.window", "Khoang thoi gian khong hop le.")));

        double hours = (end - start).TotalHours;
        long escrow = (long)Math.Round(hours * BaseHourlyPrice);
        long fee = (long)Math.Round(escrow * PlatformFeePercent);
        long earning = escrow - fee;

        string snapshot =
            $"{{\"base_hourly\":{BaseHourlyPrice},\"hours\":{hours:F2},\"fee_percent\":{PlatformFeePercent}}}";

        var quote = new PriceQuote(escrow, fee, earning, DefaultDisputeWindowHours, snapshot);
        return Task.FromResult(Result.Success(quote));
    }
}
