using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Catalog.Application.Queries.Services;

internal sealed record ListServiceChecklistTemplatesQuery(Guid ServiceId)
    : IRequest<IReadOnlyList<PublicServiceChecklistItem>?>;

internal sealed class ListServiceChecklistTemplatesQueryHandler(
    ICatalogReadStore catalog, IServiceChecklistReader checklists, IClock clock)
    : IRequestHandler<ListServiceChecklistTemplatesQuery, IReadOnlyList<PublicServiceChecklistItem>?>
{
    public async Task<IReadOnlyList<PublicServiceChecklistItem>?> Handle(
        ListServiceChecklistTemplatesQuery request, CancellationToken ct)
    {
        if (await catalog.GetActiveServiceAsync(request.ServiceId, clock.UtcNow, ct) is null)
            return null;

        return await checklists.ListActiveAsync(request.ServiceId, ct);
    }
}
