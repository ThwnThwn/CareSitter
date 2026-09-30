using CareSitter.Modules.Booking.Application;
using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Infrastructure;

public sealed class BookingResponseMapper(
    BookingDbContext db,
    IPeopleLookupService people,
    ICatalogLookupService catalog,
    IClock clock) : IBookingResponseMapper
{
    public async Task<IReadOnlyList<BookingResponse>> ToResponsesAsync(
        IReadOnlyList<Domain.Booking> bookings, CancellationToken ct, Guid? offerCaregiverId = null)
    {
        var responses = new List<BookingResponse>(bookings.Count);
        var offersByBookingId = new Dictionary<Guid, OfferMetadata>();
        if (offerCaregiverId is not null && bookings.Count > 0)
        {
            var bookingIds = bookings.Select(booking => booking.Id).ToArray();
            var offerRows = await db.BookingAssignments.AsNoTracking()
                .Where(x => x.CaregiverId == offerCaregiverId.Value
                    && bookingIds.Contains(x.BookingId)
                    && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
                    && x.ExpiresAt != null && x.ExpiresAt > clock.UtcNow)
                .ToListAsync(ct);
            offersByBookingId = offerRows
                .GroupBy(x => x.BookingId)
                .ToDictionary(
                    group => group.Key,
                    group =>
                    {
                        var offer = group.OrderByDescending(x => x.OfferedAt).First();
                        return new OfferMetadata(offer.Id, offer.ExpiresAt, offer.Rank);
                    });
        }

        var beneficiaries = new Dictionary<Guid, PeopleDisplaySummary?>();
        var caregivers = new Dictionary<Guid, PeopleDisplaySummary?>();
        var addresses = new Dictionary<Guid, AddressDisplaySummary?>();
        var locations = new Dictionary<Guid, (double Lat, double Lng)?>();
        var services = new Dictionary<Guid, ServiceDisplaySummary?>();
        foreach (var booking in bookings)
        {
            var beneficiary = await LookupOnce(beneficiaries, booking.BeneficiaryId,
                id => people.GetBeneficiaryDisplayAsync(id, ct));
            var caregiver = booking.CaregiverId is { } caregiverId
                ? await LookupOnce(caregivers, caregiverId, id => people.GetCaregiverDisplayAsync(id, ct))
                : null;
            var address = await LookupOnce(addresses, booking.AddressId,
                id => catalog.GetAddressDisplayAsync(id, ct));
            var location = await LookupOnce(locations, booking.AddressId,
                id => catalog.GetAddressLocationAsync(id, ct));
            var service = await LookupOnce(services, booking.ServiceTypeId,
                id => catalog.GetServiceDisplayAsync(id, ct));
            offersByBookingId.TryGetValue(booking.Id, out var offer);
            responses.Add(MapResponse(booking, beneficiary, caregiver, address, location, service, offer));
        }
        return responses;
    }

    public async Task<BookingResponse> ToResponseAsync(Domain.Booking booking, CancellationToken ct)
    {
        var beneficiary = await people.GetBeneficiaryDisplayAsync(booking.BeneficiaryId, ct);
        var caregiver = booking.CaregiverId is { } caregiverId
            ? await people.GetCaregiverDisplayAsync(caregiverId, ct)
            : null;
        var address = await catalog.GetAddressDisplayAsync(booking.AddressId, ct);
        var addressLocation = await catalog.GetAddressLocationAsync(booking.AddressId, ct);
        var service = await catalog.GetServiceDisplayAsync(booking.ServiceTypeId, ct);

        return MapResponse(booking, beneficiary, caregiver, address, addressLocation, service);
    }

    public CaregiverSuggestionResponse ToCaregiverSuggestion(
        MatchingCandidate candidate, PeopleDisplaySummary? display)
    {
        candidate.ScoreBreakdown.TryGetValue("travelTimeMinutes", out var travelTimeMinutes);
        return new CaregiverSuggestionResponse(
            candidate.CaregiverId,
            display?.DisplayName,
            candidate.Rank,
            candidate.Score,
            candidate.DistanceMeters,
            travelTimeMinutes == 0m ? null : travelTimeMinutes,
            candidate.ScoreBreakdown);
    }

    private static async Task<T> LookupOnce<T>(Dictionary<Guid, T> cache,
        Guid id, Func<Guid, Task<T>> fetch)
    {
        if (cache.TryGetValue(id, out var value)) return value;
        value = await fetch(id);
        cache[id] = value;
        return value;
    }

    private static BookingResponse MapResponse(Domain.Booking x,
        PeopleDisplaySummary? beneficiary, PeopleDisplaySummary? caregiver,
        AddressDisplaySummary? address, (double Lat, double Lng)? addressLocation,
        ServiceDisplaySummary? service, OfferMetadata? offer = null) =>
        new(x.Id, x.BeneficiaryId,
            x.CaregiverId, x.AddressId, x.ServiceTypeId, x.ScheduledStart, x.ScheduledEnd,
            x.ActualStart, x.ActualEnd, x.CheckoutPendingReviewAt, x.CheckoutSource?.ToString(),
            BookingStatusCodec.ToApi(x.Status), x.EscrowAmount, x.PlatformFeeAmount,
            x.CaregiverEarningAmount,
            x.CancelledAt, x.CancelReason, x.CreatedAt, x.UpdatedAt,
            x.SyncVersion,
            beneficiary?.DisplayName, caregiver?.DisplayName, address?.FullAddress, service?.Name,
            service?.Description,
            beneficiary?.Notes,
            beneficiary?.Age,
            beneficiary?.Relationship,
            beneficiary?.Condition,
            beneficiary?.Notes,
            addressLocation?.Lat,
            addressLocation?.Lng,
            offer?.Id,
            offer?.ExpiresAt,
            offer?.Rank,
            x.NeedsReview,
            x.AllowAdHocTasks,
            x.CustomerPayableAmount,
            x.PromotionDiscountAmount,
            x.PromotionSubsidyAmount,
            x.PromotionId,
            x.PromotionCode);

    private sealed record OfferMetadata(Guid Id, DateTimeOffset? ExpiresAt, int? Rank);
}
