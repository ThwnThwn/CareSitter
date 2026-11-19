using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal sealed class CreateServiceBundleCommandHandler(ISender mediator, IServiceChecklistWriter checklists,
    IServiceSetupReceipts receipts, ICurrentUser user) : IRequestHandler<CreateServiceBundleCommand, Result<AdminServiceResponse>>
{
    public async Task<Result<AdminServiceResponse>> Handle(CreateServiceBundleCommand request, CancellationToken ct)
    {
        if (user.UserId is not { } admin || !user.IsInRole("ADMIN")) return Error.Forbidden("catalog.forbidden", "Cần quyền quản trị.");
        if (request.RequestId == Guid.Empty || request.Checklist is not { Count: > 0 and <= 100 } ||
            request.Checklist.Any(x => x is null))
            return Error.Validation("catalog.setup", "Cần mã yêu cầu và từ 1 đến 100 công việc.");
        var hash = Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(
            new { request.Service, request.Price, request.Checklist })));
        var previous = await receipts.FindAsync(admin, request.RequestId, ct);
        if (previous is not null)
        {
            if (previous.PayloadHash != hash) return Error.Conflict("catalog.setup_changed", "Mã yêu cầu đã dùng cho dữ liệu khác.");
            return await mediator.Send(new GetAdminServiceQuery(previous.ServiceId), ct);
        }
        var service = await mediator.Send(request.Service, ct);
        if (service.IsFailure) return service.Error;
        var id = service.Value.Id;
        var price = await mediator.Send(request.Price with { ServiceId = id }, ct);
        if (price.IsFailure) return price.Error;
        foreach (var item in request.Checklist)
        {
            var result = await checklists.AddItemAsync(id, item, ct);
            if (result.IsFailure) return result.Error;
        }
        await receipts.SaveAsync(admin, request.RequestId, id, hash, ct);
        return await mediator.Send(new GetAdminServiceQuery(id), ct);
    }
}
