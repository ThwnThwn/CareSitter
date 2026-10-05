using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class SearchCaregiversQueryHandler(
    IPeopleReadStore store) : IRequestHandler<SearchCaregiversQuery, PeoplePage<CaregiverResponse>>
{
    public Task<PeoplePage<CaregiverResponse>> Handle(SearchCaregiversQuery request, CancellationToken ct) =>
        store.SearchCaregiversAsync(new CaregiverSearchCriteria(
            request.Latitude, request.Longitude, request.City, request.District,
            request.Skill, request.MinimumRating, request.AvailabilityStatus,
            request.Start, request.End, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50)), ct);
}
