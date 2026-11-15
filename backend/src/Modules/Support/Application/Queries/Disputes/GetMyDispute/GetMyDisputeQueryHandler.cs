using CareSitter.Contracts.Services;
using CareSitter.Modules.Support.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Support.Application;

internal sealed class GetMyDisputeQueryHandler(
    ISupportReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetMyDisputeQuery, Result<DisputeResponse>>
{
    public async Task<Result<DisputeResponse>> Handle(GetMyDisputeQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return SupportErrors.Unauthenticated();
        var dispute = await store.GetUserDisputeAsync(request.DisputeId, userId, ct);
        return dispute is null ? SupportErrors.NotFound() : dispute;
    }
}
