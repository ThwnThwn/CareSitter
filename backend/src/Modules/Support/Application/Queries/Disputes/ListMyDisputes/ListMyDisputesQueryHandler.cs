using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class ListMyDisputesQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListMyDisputesQuery, Result<IReadOnlyList<DisputeResponse>>>
{
    public async Task<Result<IReadOnlyList<DisputeResponse>>> Handle(
        ListMyDisputesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<DisputeResponse>>(
            await store.ListUserDisputesAsync(userId, ct));
    }
}
