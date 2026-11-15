using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record ChecklistTemplateResponse(
    Guid Id, Guid ServiceTypeId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, bool IsActive);
