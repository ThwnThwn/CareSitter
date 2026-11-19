using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

internal sealed class DisputePricing : IDisputePricing
{
    public Result<DisputeQuote> Quote(DisputeBookingSnapshot booking, string decision, long? refund, long? penalty)
    {
        var result = DisputeAllocation.Create(booking.EscrowAmount, booking.CustomerPayableAmount,
            booking.PromotionSubsidyAmount, booking.PlatformFeeAmount, decision, refund, penalty);
        if (result.IsFailure) return result.Error;
        var value = result.Value;
        return new DisputeQuote(value.CustomerRefund, value.PromotionReversal, value.Fee, value.Penalty, value.CaregiverEarning);
    }
}
