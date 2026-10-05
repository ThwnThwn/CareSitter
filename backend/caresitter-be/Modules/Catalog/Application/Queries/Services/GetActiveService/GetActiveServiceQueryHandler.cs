using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class GetActiveServiceQueryHandler(
    ICatalogReadStore store,
    IClock clock) : IRequestHandler<GetActiveServiceQuery, ServiceCatalogResponse?>
{
    public Task<ServiceCatalogResponse?> Handle(GetActiveServiceQuery request, CancellationToken ct) =>
        store.GetActiveServiceAsync(request.ServiceId, clock.UtcNow, ct);
}
