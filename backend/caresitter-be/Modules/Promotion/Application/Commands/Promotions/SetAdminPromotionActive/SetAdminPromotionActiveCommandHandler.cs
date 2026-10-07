using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class SetAdminPromotionActiveCommandHandler(IPromotionAdminStore store, IAuditLogger audit)
    : IRequestHandler<SetAdminPromotionActiveCommand, Result<AdminPromotionResponse>>
{
    public async Task<Result<AdminPromotionResponse>> Handle(SetAdminPromotionActiveCommand request, CancellationToken ct)
    {
        var result = await store.SetActiveAsync(request.Id, request.IsActive, request.ExpectedUpdatedAt, ct);
        if (result.IsFailure) return result.Error;
        var change = result.Value;
        await audit.WriteAsync("ADMIN_PROMOTION_ACTIVE_CHANGED", "Promotion",
            (change.After ?? change.Before)!.Id, change.Before, change.After, ct);
        return change.After!;
    }
}
