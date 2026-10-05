using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class UpdateChecklistTemplateCommandHandler(IChecklistTemplateManager manager)
    : IRequestHandler<UpdateChecklistTemplateCommand, Result<ChecklistTemplateResponse>>
{
    public Task<Result<ChecklistTemplateResponse>> Handle(
        UpdateChecklistTemplateCommand request, CancellationToken ct) =>
        manager.UpdateAsync(request.ServiceTypeId, request.TemplateId, request.Input, ct);
}
