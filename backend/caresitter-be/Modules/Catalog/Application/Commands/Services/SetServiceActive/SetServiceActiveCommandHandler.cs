using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class SetServiceActiveCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<SetServiceActiveCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(SetServiceActiveCommand request, CancellationToken ct)
    {
        var service = await repository.GetServiceAsync(request.ServiceId, ct);
        if (service is null) return Error.NotFound("catalog.service.not_found", string.Empty);

        var before = CatalogAdminMapper.ToResponse(service);
        service.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(service);
        await auditLogger.WriteAsync("ADMIN_SERVICE_ACTIVE_UPDATED", "ServiceType", service.Id,
            before, response, ct);
        return response;
    }
}
