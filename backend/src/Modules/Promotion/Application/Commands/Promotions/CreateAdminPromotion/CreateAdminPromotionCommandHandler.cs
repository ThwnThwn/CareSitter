using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class CreateAdminPromotionCommandHandler(IPromotionAdminStore store, IAuditLogger audit)
    : IRequestHandler<CreateAdminPromotionCommand, Result<AdminPromotionResponse>>
{
    public async Task<Result<AdminPromotionResponse>> Handle(CreateAdminPromotionCommand request, CancellationToken ct)
    {
        var result = await store.CreateAsync(request.Configuration, ct);
        if (result.IsFailure) return result.Error;
        var change = result.Value;
        await audit.WriteAsync("ADMIN_PROMOTION_CREATED", "Promotion",
            (change.After ?? change.Before)!.Id, change.Before, change.After, ct);
        return change.After!;
    }
}
