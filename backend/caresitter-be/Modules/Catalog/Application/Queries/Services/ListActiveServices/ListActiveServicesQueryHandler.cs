using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class ListActiveServicesQueryHandler(
    ICatalogReadStore store,
    IClock clock) : IRequestHandler<ListActiveServicesQuery, IReadOnlyList<ServiceCatalogResponse>>
{
    public Task<IReadOnlyList<ServiceCatalogResponse>> Handle(
        ListActiveServicesQuery request, CancellationToken ct) =>
        store.ListActiveServicesAsync(clock.UtcNow, ct);
}
