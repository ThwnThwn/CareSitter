using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Queries.HealthProfile;

internal sealed class GetHealthProfileQueryHandler(IBeneficiaryHealthSnapshotReader access,
    ICurrentUser user) : IRequestHandler<GetHealthProfileQuery, Result<BeneficiaryHealthSnapshot>>
{
    public async Task<Result<BeneficiaryHealthSnapshot>> Handle(GetHealthProfileQuery request, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("nutrition.unauthenticated", "Vui lòng đăng nhập lại.");
        if (!user.Roles.Contains("CUSTOMER")) return Error.Forbidden("nutrition.forbidden", "Không có quyền truy cập.");
        var snapshot = await access.ReadAsync(owner, request.BeneficiaryId, ct);
        return snapshot is null ? Error.NotFound("nutrition.profile_not_found", "Hồ sơ không còn khả dụng.") : snapshot;
    }
}
