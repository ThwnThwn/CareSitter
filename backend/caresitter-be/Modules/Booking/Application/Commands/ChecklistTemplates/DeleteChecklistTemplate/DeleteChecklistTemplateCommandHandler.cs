using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class DeleteChecklistTemplateCommandHandler(IChecklistTemplateManager manager)
    : IRequestHandler<DeleteChecklistTemplateCommand, Result>
{
    public Task<Result> Handle(DeleteChecklistTemplateCommand request, CancellationToken ct) =>
        manager.DeleteAsync(request.ServiceTypeId, request.TemplateId, ct);
}
