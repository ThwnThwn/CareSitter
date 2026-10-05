using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public sealed record SearchCaregiversQuery(
    double? Latitude,
    double? Longitude,
    string? City,
    string? District,
    string? Skill,
    decimal? MinimumRating,
    string? AvailabilityStatus,
    DateTimeOffset? Start,
    DateTimeOffset? End,
    int Page,
    int PageSize) : IRequest<PeoplePage<CaregiverResponse>>;
