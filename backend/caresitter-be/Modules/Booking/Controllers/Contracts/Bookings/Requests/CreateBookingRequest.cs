namespace CareSitter.Modules.Booking.Application.Bookings.Dtos.Requests;

public sealed record CreateBookingRequest(
    Guid BeneficiaryId,
    Guid AddressId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    Guid? CaregiverId = null,
    IReadOnlyList<string>? RequiredSkills = null,
    string? PromotionCode = null);
