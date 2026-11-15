using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class PreviewPromotionCommandHandler(
    IPromotionService promotions,
    IPricingService pricing,
    ICurrentUser currentUser)
    : IRequestHandler<PreviewPromotionCommand, Result<PromotionPreviewResponse>>
{
    public async Task<Result<PromotionPreviewResponse>> Handle(
        PreviewPromotionCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } customerId)
            return PromotionErrors.Unauthenticated();

        var baseQuote = await pricing.QuoteAsync(request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, ct);
        if (baseQuote.IsFailure) return baseQuote.Error;

        var preview = await promotions.PreviewAsync(new PromotionPriceRequest(
            request.Code, customerId, request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd,
            baseQuote.Value.EscrowAmount), ct);
        if (preview.IsFailure) return preview.Error;

        var value = preview.Value;
        return new PromotionPreviewResponse(value.PromotionId, value.Code, value.Title,
            value.GrossAmount, value.DiscountAmount, value.CustomerPayableAmount,
            value.PlatformSubsidyAmount);
    }
}
