using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record ChecklistTemplateInput(
    string Name, string? Description, bool IsRequired, bool RequiresPhoto, int SortOrder);
