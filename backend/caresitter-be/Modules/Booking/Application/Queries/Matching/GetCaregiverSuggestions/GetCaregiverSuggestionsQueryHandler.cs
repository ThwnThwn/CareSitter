using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class GetCaregiverSuggestionsQueryHandler(
    IBookingReadStore store,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMatchingService matching,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<GetCaregiverSuggestionsQuery, Result<CaregiverSuggestionListResponse>>
{
    public async Task<Result<CaregiverSuggestionListResponse>> Handle(
        GetCaregiverSuggestionsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        var booking = await store.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CustomerId != userId && !currentUser.IsInRole("ADMIN"))
            return BookingErrors.Forbidden();
        if (booking.CaregiverId.HasValue)
            return new CaregiverSuggestionListResponse([], 0);

        var limit = Math.Clamp(request.Limit, 1, 20);
        var candidates = await matching.GetSuggestedCaregiversAsync(request.BookingId, ct);
        var items = new List<CaregiverSuggestionResponse>();
        foreach (var candidate in candidates.Take(limit))
        {
            var display = await people.GetCaregiverDisplayAsync(candidate.CaregiverId, ct);
            items.Add(responseMapper.ToCaregiverSuggestion(candidate, display));
        }

        return new CaregiverSuggestionListResponse(items, candidates.Count);
    }
}
