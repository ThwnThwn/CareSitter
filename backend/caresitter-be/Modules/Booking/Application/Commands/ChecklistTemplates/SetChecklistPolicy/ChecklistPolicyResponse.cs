using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Application;

public sealed record ChecklistPolicyResponse(Guid Id, bool AllowAdHocTasks);
