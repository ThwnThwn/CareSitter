using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record SetChecklistPolicyCommand(Guid ServiceTypeId, bool AllowAdHocTasks)
    : IRequest<Result<ChecklistPolicyResponse>>;
