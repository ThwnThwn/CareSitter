using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Domain;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using static CareSitter.Modules.Booking.Application.Matching.MatchingPolicy;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Matching IO/offer orchestration. Pure rules live in Application.Matching.
/// People and Catalog data is obtained through
/// public read contracts; this service never receives their DbContexts.
/// </summary>
internal sealed class MatchingService(
    BookingDbContext bookingDb,
    IMatchingCaregiverReader caregivers,
    IMatchingAddressReader addresses,
    IPeopleLookupService people,
    IRouteMatrixService routeMatrix,
    IUserNotificationService notifications,
    IHubContext<CareTrackingHub> hub,
    IOptions<MatchingOptions> options,
    ILogger<MatchingService> logger) : IMatchingService
{
    private MatchingOptions Config => options.Value;

    public Task<IReadOnlyList<MatchingCandidate>> GetEligibleCaregiversAsync(
        Guid bookingId, CancellationToken ct = default) =>
        GetRankedCaregiversAsync(bookingId, allowPrePayment: false, ct);

    public Task<IReadOnlyList<MatchingCandidate>> GetSuggestedCaregiversAsync(
        Guid bookingId, CancellationToken ct = default) =>
        GetRankedCaregiversAsync(bookingId, allowPrePayment: true, ct);

    private async Task<IReadOnlyList<MatchingCandidate>> GetRankedCaregiversAsync(
        Guid bookingId, bool allowPrePayment, CancellationToken ct)
    {
        var booking = await bookingDb.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null || booking.CaregiverId is not null ||
            !CanRankCaregiversForStatus(booking.Status, allowPrePayment))
            return Array.Empty<MatchingCandidate>();

        var address = await addresses.GetAsync(booking.AddressId, ct);
        if (address?.Location is null)
            return Array.Empty<MatchingCandidate>();

        var profiles = await caregivers.ListAvailableAsync(ct);
        if (profiles.Count == 0)
            return Array.Empty<MatchingCandidate>();

        var caregiverIds = profiles.Select(x => x.Id).ToArray();
        var conflicts = await bookingDb.Bookings.AsNoTracking()
            .Where(x => x.CaregiverId != null && caregiverIds.Contains(x.CaregiverId.Value)
                && x.Status != BookingStatus.Completed
                && x.Status != BookingStatus.Cancelled
                && x.Status != BookingStatus.Refunded
                && x.Status != BookingStatus.MatchingFailed
                && x.ScheduledStart < booking.ScheduledEnd
                && x.ScheduledEnd > booking.ScheduledStart)
            .Select(x => new CaregiverBookingWindow(
                x.CaregiverId!.Value, x.Id, x.ScheduledStart, x.ScheduledEnd))
            .ToListAsync(ct);
        var rejected = (await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.BookingId == bookingId && x.Status == "REJECTED")
            .Select(x => x.CaregiverId)
            .ToListAsync(ct)).ToHashSet();

        var requiredSkills = ParseSkills(booking.RequiredSkills);
        var eligible = new List<EligibleCandidate>();
        foreach (var profile in profiles)
        {
            if (rejected.Contains(profile.Id) || !IsEligible(
                    profile, booking, address,
                    conflicts.Where(x => x.CaregiverId == profile.Id), Config))
                continue;

            eligible.Add(PrepareCandidate(profile, address, requiredSkills));
        }

        var shortlist = Shortlist(eligible, Config);
        if (shortlist.Length == 0)
            return Array.Empty<MatchingCandidate>();

        var routes = await routeMatrix.CalculateAsync(
            shortlist.Select(x => x.Origin!).ToArray(), address.Location, ct);
        return Rank(shortlist, routes, Config);
    }

    public async Task<IReadOnlyList<Guid>> GetOpenBookingIdsForCaregiverAsync(
        Guid caregiverId, CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var openBookings = bookingDb.Bookings.AsNoTracking()
            .Where(x => x.CaregiverId == null && x.Status == BookingStatus.Confirmed);
        return (await bookingDb.BookingAssignments.AsNoTracking()
                .Where(x => x.CaregiverId == caregiverId
                    && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
                    && x.ExpiresAt != null && x.ExpiresAt > now)
                .Join(openBookings, x => x.BookingId, x => x.Id, (_, booking) => booking.Id)
                .ToListAsync(ct))
            .Distinct()
            .ToArray();
    }

    public async Task<IReadOnlyList<MatchingCandidate>> OfferTopCandidatesAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        var booking = await bookingDb.Bookings.SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null || booking.Status != BookingStatus.Confirmed || booking.CaregiverId is not null)
            return Array.Empty<MatchingCandidate>();

        var eligible = await GetEligibleCaregiversAsync(bookingId, ct);
        if (eligible.Count == 0)
        {
            await MarkMatchingFailedAsync(booking, ct);
            return Array.Empty<MatchingCandidate>();
        }

        var assigned = (await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.BookingId == bookingId)
            .Select(x => x.CaregiverId)
            .ToListAsync(ct)).ToHashSet();
        var selected = eligible.Where(x => !assigned.Contains(x.CaregiverId))
            .Take(Math.Max(1, Config.InitialOfferCount)).ToArray();
        if (selected.Length == 0)
        {
            await MarkMatchingFailedAsync(booking, ct);
            return Array.Empty<MatchingCandidate>();
        }

        await PersistOffersAsync(bookingId, selected, ct);
        return selected;
    }

    public async Task<int> ExpandExpiredOffersAsync(CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var bookingIds = await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.Status == "OFFERED" && x.ExpiresAt != null && x.ExpiresAt <= now)
            .Select(x => x.BookingId).Distinct().ToListAsync(ct);
        var expanded = 0;

        foreach (var bookingId in bookingIds)
        {
            var booking = await bookingDb.Bookings.SingleOrDefaultAsync(x =>
                x.Id == bookingId && x.Status == BookingStatus.Confirmed && x.CaregiverId == null, ct);
            if (booking is null) continue;
            if (await bookingDb.BookingAssignments.AsNoTracking().AnyAsync(x =>
                    x.BookingId == bookingId && x.Status == "OFFERED" &&
                    x.ExpiresAt != null && x.ExpiresAt > now, ct))
                continue;

            var expired = await bookingDb.BookingAssignments.Where(x =>
                x.BookingId == bookingId && x.Status == "OFFERED" &&
                x.ExpiresAt != null && x.ExpiresAt <= now).ToListAsync(ct);
            foreach (var assignment in expired) assignment.MarkExpired();
            await bookingDb.SaveChangesAsync(ct);
            foreach (var assignment in expired)
                await PublishOfferChangedAsync(assignment.CaregiverId, bookingId, "expired", ct);

            expanded += (await OfferExpansionBatchAsync(booking, ct)).Count;
        }

        return expanded;
    }

    private async Task<IReadOnlyList<MatchingCandidate>> OfferExpansionBatchAsync(
        Domain.Booking booking, CancellationToken ct)
    {
        var eligible = await GetEligibleCaregiversAsync(booking.Id, ct);
        var existing = (await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.BookingId == booking.Id)
            .Select(x => x.CaregiverId).ToListAsync(ct)).ToHashSet();
        var selected = eligible.Where(x => !existing.Contains(x.CaregiverId))
            .Take(Math.Max(1, Config.ExpansionOfferCount)).ToArray();
        if (selected.Length == 0)
        {
            await MarkMatchingFailedAsync(booking, ct);
            return Array.Empty<MatchingCandidate>();
        }

        await PersistOffersAsync(booking.Id, selected, ct);
        return selected;
    }

    private async Task PersistOffersAsync(
        Guid bookingId, IReadOnlyCollection<MatchingCandidate> selected, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var expiresAt = now.AddMinutes(Math.Max(1, Config.OfferLifetimeMinutes));
        foreach (var candidate in selected)
        {
            bookingDb.BookingAssignments.Add(BookingAssignment.CreateOffered(
                bookingId, candidate.CaregiverId, candidate.Rank, candidate.DistanceMeters,
                candidate.Score, JsonSerializer.Serialize(candidate.ScoreBreakdown), now, expiresAt));
        }
        await bookingDb.SaveChangesAsync(ct);
        foreach (var candidate in selected)
            await NotifyOfferAsync(bookingId, candidate, ct);
        logger.LogInformation("Created {Count} caregiver offers for booking {BookingId}.",
            selected.Count, bookingId);
    }

    private async Task MarkMatchingFailedAsync(Domain.Booking booking, CancellationToken ct)
    {
        if (booking.Status != BookingStatus.Confirmed || booking.CaregiverId is not null)
            return;
        var result = booking.MarkMatchingFailed();
        if (result.IsFailure)
        {
            logger.LogWarning("Could not mark booking {BookingId} as matching failed: {Reason}",
                booking.Id, result.Error.Message);
            return;
        }
        await bookingDb.SaveChangesAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(booking.Id))
            .SendAsync("BookingStatusChanged", new BookingStatusChangedEvent(
                booking.Id, "confirmed", "matching_failed", DateTimeOffset.UtcNow), ct);
        await notifications.NotifyAsync(new UserNotificationMessage(
            booking.CustomerId, "MATCHING_FAILED", "Chưa tìm thấy người chăm sóc phù hợp",
            "Hiện chưa có người chăm sóc phù hợp nhận ca này. Bạn có thể đổi lịch hoặc chọn thủ công.",
            new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["status"] = "matching_failed",
                ["deepLink"] = $"/bookings/{booking.Id}"
            }), ct);
    }

    private async Task NotifyOfferAsync(
        Guid bookingId, MatchingCandidate candidate, CancellationToken ct)
    {
        var userId = await people.GetUserIdByCaregiverProfileIdAsync(candidate.CaregiverId, ct);
        if (userId is null) return;
        await notifications.NotifyAsync(new UserNotificationMessage(
            userId.Value, "BOOKING_OFFER", "Bạn có ca chăm sóc phù hợp",
            "Một khách hàng đang cần bạn xác nhận ca chăm sóc.",
            new Dictionary<string, string>
            {
                ["bookingId"] = bookingId.ToString(),
                ["status"] = "confirmed",
                ["deepLink"] = $"/shifts/{bookingId}"
            }), ct);
        await hub.Clients.Group(CareTrackingHub.CaregiverGroup(userId.Value))
            .SendAsync("BookingOfferChanged", new BookingOfferChangedEvent(
                bookingId, "created", DateTimeOffset.UtcNow), ct);
    }

    private async Task PublishOfferChangedAsync(
        Guid caregiverId, Guid bookingId, string changeType, CancellationToken ct)
    {
        var userId = await people.GetUserIdByCaregiverProfileIdAsync(caregiverId, ct);
        if (userId is null) return;
        await hub.Clients.Group(CareTrackingHub.CaregiverGroup(userId.Value))
            .SendAsync("BookingOfferChanged", new BookingOfferChangedEvent(
                bookingId, changeType, DateTimeOffset.UtcNow), ct);
    }

}
