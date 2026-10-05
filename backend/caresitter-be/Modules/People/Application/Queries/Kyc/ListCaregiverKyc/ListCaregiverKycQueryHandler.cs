using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class ListCaregiverKycQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListCaregiverKycQuery, Result<PeoplePage<CaregiverKycResponse>>>
{
    public async Task<Result<PeoplePage<CaregiverKycResponse>>> Handle(
        ListCaregiverKycQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();
        var page = Math.Max(request.Page, 1);
        var pageSize = Math.Clamp(request.PageSize, 1, 50);
        return await store.ListCaregiverKycAsync(request.Status, page, pageSize, ct);
    }
}
