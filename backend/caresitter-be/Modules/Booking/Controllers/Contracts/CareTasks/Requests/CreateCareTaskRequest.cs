using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.Controllers;

public sealed record CreateCareTaskRequest(
    string Name, string? Description = null,
    bool IsRequired = false, bool RequiresPhoto = false, int SortOrder = 0);
