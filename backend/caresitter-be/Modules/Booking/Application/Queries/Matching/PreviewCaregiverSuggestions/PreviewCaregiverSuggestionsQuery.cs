using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record PreviewCaregiverSuggestionsQuery(
    Guid? BeneficiaryId, Guid AddressId, Guid ServiceTypeId,
    DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd,
    IReadOnlyList<string>? RequiredSkills = null, int Limit = 10)
    : IRequest<Result<CaregiverSuggestionListResponse>>;
