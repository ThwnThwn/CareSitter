using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class GetAdminDisputeQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetAdminDisputeQuery, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(GetAdminDisputeQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        var dispute = await store.GetDisputeAsync(request.DisputeId, ct);
        return dispute is null ? SupportErrors.NotFound() : dispute;
    }
}
