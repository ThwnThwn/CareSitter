using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

internal sealed class GetSelfBeneficiaryQueryHandler(IPeopleRepository repository, ICurrentUser currentUser)
    : IRequestHandler<GetSelfBeneficiaryQuery, Result<BeneficiaryResponse>>
{
    public async Task<Result<BeneficiaryResponse>> Handle(GetSelfBeneficiaryQuery request, CancellationToken ct)
    {
        if (SelfBeneficiaryRules.Authorize(currentUser) is { } error) return error;
        var userId = currentUser.UserId!.Value;
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var entity = await repository.GetSelfBeneficiaryAsync(userId, ct);
        if (entity is null) return Error.NotFound("beneficiary.self_not_found", "Chưa có hồ sơ bản thân.");
        if (entity.DeletedAt is not null) return SelfBeneficiaryRules.Archived();
        return PeopleResponseMapper.ToResponse(entity);
    }
}
