using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class ListChecklistTemplatesQueryHandler(IChecklistTemplateManager manager)
    : IRequestHandler<ListChecklistTemplatesQuery, Result<IReadOnlyList<ChecklistTemplateResponse>>>
{
    public Task<Result<IReadOnlyList<ChecklistTemplateResponse>>> Handle(
        ListChecklistTemplatesQuery request, CancellationToken ct) =>
        manager.ListAsync(request.ServiceTypeId, ct);
}
