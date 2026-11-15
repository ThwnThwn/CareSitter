namespace CareSitter.Modules.Booking.Controllers;

public sealed record PreviewCaregiverSuggestionsRequest(
    Guid? BeneficiaryId, Guid AddressId, Guid ServiceTypeId,
    DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd,
    IReadOnlyList<string>? RequiredSkills = null, int Limit = 10);
