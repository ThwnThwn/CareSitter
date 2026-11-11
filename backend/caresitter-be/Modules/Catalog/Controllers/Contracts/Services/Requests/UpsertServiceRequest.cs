using CareSitter.Modules.Catalog.Application;

namespace CareSitter.Modules.Catalog.Controllers;

public sealed record UpsertServiceRequest(
    string Code,
    string Name,
    string? Description,
    string? ImageUrl,
    int DefaultDurationMinutes = 60,
    bool IsActive = true);
