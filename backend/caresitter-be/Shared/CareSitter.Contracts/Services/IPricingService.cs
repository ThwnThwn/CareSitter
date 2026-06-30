using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>Catalog cung cap bao gia cho Booking (dong bo, qua DI). Cam query DbContext cheo module.</summary>
public interface IPricingService
{
    Task<Result<PriceQuote>> QuoteAsync(Guid serviceTypeId, DateTimeOffset start, DateTimeOffset end,
        CancellationToken ct = default);
}

public sealed record PriceQuote(
    long EscrowAmount,
    long PlatformFeeAmount,
    long CaregiverEarningAmount,
    int DisputeWindowHours,
    string PriceSnapshotJson);
