using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

public sealed record PreviewPromotionCommand(
    string Code,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd) : IRequest<Result<PromotionPreviewResponse>>;
