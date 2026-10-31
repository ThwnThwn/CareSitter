using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class CreateServiceCommandHandler(
    ICatalogAdminRepository repository,
    IAuditLogger auditLogger) : IRequestHandler<CreateServiceCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(CreateServiceCommand request, CancellationToken ct)
    {
        var code = request.Code?.Trim().ToUpperInvariant() ?? string.Empty;
        if (await repository.ServiceCodeExistsAsync(code, ct: ct))
            return Error.Conflict("catalog.service.code_exists", "Mã dịch vụ đã tồn tại.");

        var created = ServiceType.Create(code, request.Name, request.Description,
            request.DefaultDurationMinutes, request.IsActive, request.ImageUrl);
        if (created.IsFailure) return created.Error;

        repository.Add(created.Value);
        await repository.SaveChangesAsync(ct);
        var response = CatalogAdminMapper.ToResponse(created.Value);
        await auditLogger.WriteAsync("ADMIN_SERVICE_CREATED", "ServiceType", created.Value.Id,
            null, response, ct);
        return response;
    }
}
