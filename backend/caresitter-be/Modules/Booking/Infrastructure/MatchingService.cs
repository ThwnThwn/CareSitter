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

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Booking-owned matching policy. People and Catalog data is obtained through
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
                    conflicts.Where(x => x.CaregiverId == profile.Id)))
                continue;

            var straightLineDistance = DistanceMeters(profile.ServiceCenter, address.Location);
            var skillMatch = SkillMatchScore(requiredSkills, ParseSkills(profile.Skills));
            var ratingScore = profile.RatingCount == 0
                ? 0.5m
                : Math.Clamp(profile.RatingAverage / 5m, 0m, 1m);
            var experienceScore = Math.Clamp((profile.YearsOfExperience ?? 0) / 10m, 0m, 1m);
            eligible.Add(new EligibleCandidate(
                profile.Id, profile.ServiceCenter, straightLineDistance,
                ratingScore, skillMatch, experienceScore));
        }

        var shortlist = eligible
            .Where(x => x.Origin is not null)
            .OrderBy(x => x.StraightLineDistanceMeters ?? int.MaxValue)
            .Take(Math.Max(1, Config.RouteCandidateLimit))
            .ToArray();
        if (shortlist.Length == 0)
            return Array.Empty<MatchingCandidate>();

        var routes = await routeMatrix.CalculateAsync(
            shortlist.Select(x => x.Origin!).ToArray(), address.Location, ct);
        var routeByOrigin = routes.ToDictionary(x => x.OriginIndex);
        return shortlist.Select((candidate, index) =>
            {
                routeByOrigin.TryGetValue(index, out var route);
                return route?.IsRoutable == true ? Score(candidate, route) : null;
            })
            .OfType<ScoredCandidate>()
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.DurationSeconds ?? int.MaxValue)
            .ThenBy(x => x.DistanceMeters ?? int.MaxValue)
            .Select((x, index) => new MatchingCandidate(
                x.CaregiverId, index + 1, decimal.Round(x.Score, 4),
                x.DistanceMeters, x.ScoreBreakdown))
            .ToArray();
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

    private bool IsEligible(
        MatchingCaregiverProfile profile,
        Domain.Booking booking,
        MatchingAddress address,
        IEnumerable<CaregiverBookingWindow> conflicts)
    {
        if (profile.DeletedAt is not null || profile.KycStatus != "APPROVED" ||
            profile.AvailabilityStatus != "ONLINE")
            return false;
        if (conflicts.Any(x => x.BookingId != booking.Id &&
            x.ScheduledStart < booking.ScheduledEnd && x.ScheduledEnd > booking.ScheduledStart))
            return false;
        var distance = DistanceMeters(profile.ServiceCenter, address.Location);
        if (!AreaMatches(profile, address, distance, Config.MaxDistanceMeters))
            return false;
        var required = ParseSkills(booking.RequiredSkills);
        if (required.Count > 0 && SkillMatchScore(required, ParseSkills(profile.Skills)) < 1m)
            return false;
        return profile.RatingCount <= 0 || profile.RatingAverage >= Config.MinimumRating;
    }

    internal static bool AreaMatches(
        MatchingCaregiverProfile profile, MatchingAddress address,
        int? distance, int maxDistanceMeters)
    {
        if (distance is { } meters)
            return meters <= (profile.ServiceRadiusMeters ?? maxDistanceMeters);
        return !string.IsNullOrWhiteSpace(profile.ServiceDistrict) &&
            !string.IsNullOrWhiteSpace(address.District) &&
            !string.IsNullOrWhiteSpace(profile.ServiceCity) &&
            !string.IsNullOrWhiteSpace(address.City) &&
            Normalize(profile.ServiceDistrict) == Normalize(address.District) &&
            Normalize(profile.ServiceCity) == Normalize(address.City);
    }

    private static int? DistanceMeters(GeoPoint? from, GeoPoint? to)
    {
        if (from is null || to is null) return null;
        const double earthRadius = 6371000d;
        var lat1 = from.Latitude * Math.PI / 180d;
        var lat2 = to.Latitude * Math.PI / 180d;
        var deltaLat = (to.Latitude - from.Latitude) * Math.PI / 180d;
        var deltaLng = (to.Longitude - from.Longitude) * Math.PI / 180d;
        var a = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2) +
            Math.Cos(lat1) * Math.Cos(lat2) *
            Math.Sin(deltaLng / 2) * Math.Sin(deltaLng / 2);
        return (int)Math.Round(earthRadius * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a)));
    }

    private static decimal SkillMatchScore(IReadOnlySet<string> required, IReadOnlySet<string> actual)
    {
        if (required.Count == 0) return 1m;
        var matched = required.Count(skill => actual.Any(candidate =>
            candidate.Contains(skill, StringComparison.OrdinalIgnoreCase) ||
            skill.Contains(candidate, StringComparison.OrdinalIgnoreCase)));
        return (decimal)matched / required.Count;
    }

    internal static HashSet<string> ParseSkills(string? raw)
    {
        var skills = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(raw)) return skills;
        var trimmed = raw.Trim();
        try
        {
            if (trimmed.StartsWith('[') || trimmed.StartsWith('{'))
            {
                using var document = JsonDocument.Parse(trimmed);
                if (document.RootElement.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in document.RootElement.EnumerateArray())
                    {
                        string? value = item.ValueKind == JsonValueKind.String ? item.GetString() : null;
                        if (value is null && item.ValueKind == JsonValueKind.Object)
                        {
                            value = item.EnumerateObject()
                                .Where(x => x.Name is "name" or "code" or "label")
                                .Select(x => x.Value.ValueKind == JsonValueKind.String
                                    ? x.Value.GetString() : null)
                                .FirstOrDefault(x => !string.IsNullOrWhiteSpace(x));
                        }
                        if (!string.IsNullOrWhiteSpace(value)) skills.Add(Normalize(value));
                    }
                    return skills;
                }
            }
        }
        catch (JsonException)
        {
            // Delimited legacy values are parsed below.
        }

        foreach (var token in trimmed.Split([',', ';', '\n', '\r'],
                     StringSplitOptions.RemoveEmptyEntries))
        {
            var clean = token.Trim().Trim('"', '\'', '[', ']');
            if (!string.IsNullOrWhiteSpace(clean)) skills.Add(Normalize(clean));
        }
        return skills;
    }

    private static string Normalize(string value) =>
        string.Join(' ', value.Trim().ToLowerInvariant()
            .Split(' ', StringSplitOptions.RemoveEmptyEntries));

    private static bool CanRankCaregiversForStatus(BookingStatus status, bool allowPrePayment) =>
        status == BookingStatus.Confirmed ||
        (allowPrePayment && status is BookingStatus.Draft or BookingStatus.PendingPayment);

    private ScoredCandidate Score(EligibleCandidate candidate, RouteMatrixItem route)
    {
        var distanceScore = route.DistanceMeters is null
            ? 0m
            : Math.Clamp(1m - (decimal)route.DistanceMeters.Value / Config.MaxDistanceMeters, 0m, 1m);
        var breakdown = new Dictionary<string, decimal>
        {
            ["distance"] = distanceScore,
            ["rating"] = candidate.RatingScore,
            ["skillMatch"] = candidate.SkillMatchScore,
            ["experience"] = candidate.ExperienceScore
        };
        if (route.DurationSeconds is { } seconds)
            breakdown["travelTimeMinutes"] = decimal.Round(seconds / 60m, 2);
        var score = distanceScore * Config.Weights.Distance +
            candidate.RatingScore * Config.Weights.Rating +
            candidate.SkillMatchScore * Config.Weights.SkillMatch +
            candidate.ExperienceScore * Config.Weights.Experience;
        return new ScoredCandidate(candidate.CaregiverId, score,
            route.DistanceMeters, route.DurationSeconds, breakdown);
    }

    private sealed record CaregiverBookingWindow(
        Guid CaregiverId, Guid BookingId, DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
    private sealed record EligibleCandidate(
        Guid CaregiverId, GeoPoint? Origin, int? StraightLineDistanceMeters,
        decimal RatingScore, decimal SkillMatchScore, decimal ExperienceScore);
    private sealed record ScoredCandidate(
        Guid CaregiverId, decimal Score, int? DistanceMeters, int? DurationSeconds,
        IReadOnlyDictionary<string, decimal> ScoreBreakdown);
}
