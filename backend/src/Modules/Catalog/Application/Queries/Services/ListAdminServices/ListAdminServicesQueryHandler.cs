using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class ListAdminServicesQueryHandler(
    ICatalogReadStore store) : IRequestHandler<ListAdminServicesQuery, IReadOnlyList<AdminServiceResponse>>
{
    public Task<IReadOnlyList<AdminServiceResponse>> Handle(
        ListAdminServicesQuery request, CancellationToken ct) => store.ListAdminServicesAsync(ct);
}
