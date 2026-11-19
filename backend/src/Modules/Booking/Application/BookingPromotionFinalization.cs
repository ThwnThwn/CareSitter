using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingPromotionFinalization
{
    public static async Task<Result> RunAsync(Domain.Booking booking, IWalletService wallet,
        IPromotionService promotions, CancellationToken ct)
    {
        if (booking.PromotionId is null) return Result.Success();
        var subsidy = await wallet.RecordPromotionSubsidyAsync(booking.Id, booking.PromotionSubsidyAmount, ct);
        if (subsidy.IsFailure) return subsidy;
        return await promotions.RedeemAsync(booking.Id, booking.CustomerId, ct);
    }
}
