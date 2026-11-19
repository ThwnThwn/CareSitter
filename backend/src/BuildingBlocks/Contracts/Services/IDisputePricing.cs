using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

public sealed record DisputeQuote(long Refund, long PromotionReversal, long Fee, long Penalty, long Earning);

public interface IDisputePricing
{
    Result<DisputeQuote> Quote(DisputeBookingSnapshot booking, string decision, long? refund, long? penalty);
}
