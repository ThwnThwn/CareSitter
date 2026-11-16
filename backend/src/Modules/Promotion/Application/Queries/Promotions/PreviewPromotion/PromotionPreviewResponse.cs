using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Promotion.Application;

public sealed record PromotionPreviewResponse(
    Guid PromotionId,
    string Code,
    string Title,
    long GrossAmount,
    long DiscountAmount,
    long CustomerPayableAmount,
    long PlatformSubsidyAmount);
