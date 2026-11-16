using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record PreviewPromotionQuery(
    string Code,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<PromotionPreviewResponse>>;
