using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class GetCaregiverKycQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetCaregiverKycQuery, Result<CaregiverKycResponse>>
{
    public async Task<Result<CaregiverKycResponse>> Handle(GetCaregiverKycQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();
        var profile = await store.GetCaregiverKycAsync(request.CaregiverId, ct);
        return profile is null ? PeopleErrors.CaregiverProfileNotFound() : profile;
    }
}
