using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class UpdateServiceCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<UpdateServiceCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(UpdateServiceCommand request, CancellationToken ct)
    {
        var service = await repository.GetServiceAsync(request.ServiceId, ct);
        if (service is null) return Error.NotFound("catalog.service.not_found", string.Empty);

        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await repository.ServiceCodeExistsAsync(code, request.ServiceId, ct))
            return Error.Conflict("catalog.service.code_exists", "Mã dịch vụ đã tồn tại.");

        var before = CatalogAdminMapper.ToResponse(service);
        var updated = service.Update(code, request.Name, request.Description, request.DefaultDurationMinutes);
        if (updated.IsFailure) return updated.Error;
        service.SetActive(request.IsActive);
        await repository.SaveChangesAsync(ct);

        var response = CatalogAdminMapper.ToResponse(service);
        await auditLogger.WriteAsync("ADMIN_SERVICE_UPDATED", "ServiceType", service.Id,
            before, response, ct);
        return response;
    }
}
