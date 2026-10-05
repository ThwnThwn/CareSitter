using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class SetChecklistTemplateActiveCommandHandler(IChecklistTemplateManager manager)
    : IRequestHandler<SetChecklistTemplateActiveCommand, Result<ChecklistTemplateResponse>>
{
    public Task<Result<ChecklistTemplateResponse>> Handle(
        SetChecklistTemplateActiveCommand request, CancellationToken ct) =>
        manager.SetActiveAsync(request.ServiceTypeId, request.TemplateId, request.IsActive, ct);
}
