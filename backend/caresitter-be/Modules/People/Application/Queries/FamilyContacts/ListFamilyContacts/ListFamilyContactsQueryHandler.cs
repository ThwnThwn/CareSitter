using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class ListFamilyContactsQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListFamilyContactsQuery, Result<IReadOnlyList<FamilyContactResponse>>>
{
    public async Task<Result<IReadOnlyList<FamilyContactResponse>>> Handle(
        ListFamilyContactsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<FamilyContactResponse>>(
            await store.ListFamilyContactsAsync(userId, ct));
    }
}
