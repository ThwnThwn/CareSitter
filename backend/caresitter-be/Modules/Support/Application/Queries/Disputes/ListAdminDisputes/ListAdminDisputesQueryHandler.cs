using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class ListAdminDisputesQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListAdminDisputesQuery, Result<SupportPage<DisputeResponse>>>
{
    public async Task<Result<SupportPage<DisputeResponse>>> Handle(
        ListAdminDisputesQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return SupportErrors.Forbidden();
        return await store.ListDisputesAsync(request.Status, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50), ct);
    }
}
