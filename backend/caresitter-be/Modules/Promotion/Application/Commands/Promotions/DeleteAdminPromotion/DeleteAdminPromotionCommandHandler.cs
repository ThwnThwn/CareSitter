using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class DeleteAdminPromotionCommandHandler(IPromotionAdminStore store, IAuditLogger audit)
    : IRequestHandler<DeleteAdminPromotionCommand, Result<bool>>
{
    public async Task<Result<bool>> Handle(DeleteAdminPromotionCommand request, CancellationToken ct)
    {
        var result = await store.DeleteAsync(request.Id, request.ExpectedUpdatedAt, ct);
        if (result.IsFailure) return result.Error;
        var change = result.Value;
        await audit.WriteAsync("ADMIN_PROMOTION_DELETED", "Promotion",
            (change.After ?? change.Before)!.Id, change.Before, change.After, ct);
        return true;
    }
}
