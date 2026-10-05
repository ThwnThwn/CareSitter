using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class GetBeneficiaryQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetBeneficiaryQuery, Result<BeneficiaryResponse>>
{
    public async Task<Result<BeneficiaryResponse>> Handle(GetBeneficiaryQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var beneficiary = await store.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        return beneficiary is null ? PeopleErrors.NotFound() : beneficiary;
    }
}
