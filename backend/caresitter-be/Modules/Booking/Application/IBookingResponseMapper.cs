using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Booking.Application;

public interface IBookingResponseMapper
{
    Task<IReadOnlyList<BookingResponse>> ToResponsesAsync(
        IReadOnlyList<Domain.Booking> bookings, CancellationToken ct,
        Guid? offerCaregiverId = null);
    Task<BookingResponse> ToResponseAsync(Domain.Booking booking, CancellationToken ct);
    CaregiverSuggestionResponse ToCaregiverSuggestion(
        MatchingCandidate candidate, PeopleDisplaySummary? display);
}
