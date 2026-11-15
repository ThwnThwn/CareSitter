using CareSitter.Modules.Promotion.Application;

namespace CareSitter.Modules.Promotion.Controllers;

public sealed record PromotionPreviewRequest(
    string Code,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd);
