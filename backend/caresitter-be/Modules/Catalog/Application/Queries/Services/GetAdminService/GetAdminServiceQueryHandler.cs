using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class GetAdminServiceQueryHandler(ICatalogReadStore store)
    : IRequestHandler<GetAdminServiceQuery, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(
        GetAdminServiceQuery request, CancellationToken ct)
    {
        var service = await store.GetAdminServiceAsync(request.ServiceId, ct);
        return service is null
            ? Error.NotFound("catalog.service.not_found", "Không tìm thấy gói dịch vụ.")
            : service;
    }
}
