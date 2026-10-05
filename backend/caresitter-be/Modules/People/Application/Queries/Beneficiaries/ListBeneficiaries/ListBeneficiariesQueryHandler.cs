using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class ListBeneficiariesQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListBeneficiariesQuery, Result<IReadOnlyList<BeneficiaryResponse>>>
{
    public async Task<Result<IReadOnlyList<BeneficiaryResponse>>> Handle(
        ListBeneficiariesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<BeneficiaryResponse>>(
            await store.ListBeneficiariesAsync(userId, ct));
    }
}
