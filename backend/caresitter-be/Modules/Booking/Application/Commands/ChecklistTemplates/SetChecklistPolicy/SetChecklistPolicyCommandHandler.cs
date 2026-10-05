using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class SetChecklistPolicyCommandHandler(IChecklistTemplateManager manager)
    : IRequestHandler<SetChecklistPolicyCommand, Result<ChecklistPolicyResponse>>
{
    public Task<Result<ChecklistPolicyResponse>> Handle(SetChecklistPolicyCommand request, CancellationToken ct) =>
        manager.SetPolicyAsync(request.ServiceTypeId, request.AllowAdHocTasks, ct);
}
