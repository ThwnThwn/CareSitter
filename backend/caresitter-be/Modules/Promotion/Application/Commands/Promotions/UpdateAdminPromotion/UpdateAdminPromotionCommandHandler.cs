using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class UpdateAdminPromotionCommandHandler(IPromotionAdminStore store, IAuditLogger audit)
    : IRequestHandler<UpdateAdminPromotionCommand, Result<AdminPromotionResponse>>
{
    public async Task<Result<AdminPromotionResponse>> Handle(UpdateAdminPromotionCommand request, CancellationToken ct)
    {
        var result = await store.UpdateAsync(request.Id, request.Configuration, request.ExpectedUpdatedAt, ct);
        if (result.IsFailure) return result.Error;
        var change = result.Value;
        await audit.WriteAsync("ADMIN_PROMOTION_UPDATED", "Promotion",
            (change.After ?? change.Before)!.Id, change.Before, change.After, ct);
        return change.After!;
    }
}
