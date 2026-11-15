using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class GetApprovedCaregiverQueryHandler(
    IPeopleReadStore store) : IRequestHandler<GetApprovedCaregiverQuery, CaregiverResponse?>
{
    public Task<CaregiverResponse?> Handle(GetApprovedCaregiverQuery request, CancellationToken ct) =>
        store.GetApprovedCaregiverAsync(request.CaregiverId, ct);
}
