using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class CreateChecklistTemplateCommandHandler(IChecklistTemplateManager manager)
    : IRequestHandler<CreateChecklistTemplateCommand, Result<ChecklistTemplateResponse>>
{
    public Task<Result<ChecklistTemplateResponse>> Handle(
        CreateChecklistTemplateCommand request, CancellationToken ct) =>
        manager.CreateAsync(request.ServiceTypeId, request.Input, ct);
}
