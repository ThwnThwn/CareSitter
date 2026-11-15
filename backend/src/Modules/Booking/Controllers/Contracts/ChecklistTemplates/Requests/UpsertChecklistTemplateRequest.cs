using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.Controllers;

public sealed record UpsertChecklistTemplateRequest(
    string Name, string? Description, bool IsRequired, bool RequiresPhoto, int SortOrder);
