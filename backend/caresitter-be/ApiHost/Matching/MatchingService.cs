using System.Text.Json;
using CareSitter.ApiHost.Routing;
using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using NetTopologySuite.Geometries;

namespace CareSitter.ApiHost.Matching;

/// <summary>
/// Cross-module matching orchestration.
/// Hard filter is evaluated against KYC, area, skills, availability, conflicts and rejects.
/// Soft ranking is kept configurable and persisted to booking_assignments for auditability.
/// </summary>
public sealed class MatchingService(
    BookingDbContext bookingDb,
    PeopleDbContext peopleDb,
    CatalogDbContext catalogDb,
    IPeopleLookupService peopleLookup,
    IRouteMatrixService routeMatrix,
    IUserNotificationService notifications,
    IHubContext<CareTrackingHub> hub,
    IOptions<MatchingOptions> options,
    IOptions<RoutingOptions> routingOptions,
    ILogger<MatchingService> logger) : IMatchingService
{
    private MatchingOptions Config => options.Value;
    private RoutingOptions RoutingConfig => routingOptions.Value;

    public async Task<IReadOnlyList<MatchingCandidate>> GetEligibleCaregiversAsync(
        Guid bookingId, CancellationToken ct = default) =>
        await GetRankedCaregiversAsync(bookingId, allowPrePayment: false, ct);

    public async Task<IReadOnlyList<MatchingCandidate>> GetSuggestedCaregiversAsync(
        Guid bookingId, CancellationToken ct = default) =>
        await GetRankedCaregiversAsync(bookingId, allowPrePayment: true, ct);

    private async Task<IReadOnlyList<MatchingCandidate>> GetRankedCaregiversAsync(
        Guid bookingId, bool allowPrePayment, CancellationToken ct)
    {
        var booking = await bookingDb.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null || booking.CaregiverId is not null)
            return Array.Empty<MatchingCandidate>();
        if (!CanRankCaregiversForStatus(booking.Status, allowPrePayment))
            return Array.Empty<MatchingCandidate>();

        var addressRow = await catalogDb.Addresses.AsNoTracking()
            .Where(x => x.Id == booking.AddressId)
            .Select(x => new { x.District, x.City, x.Location })
            .SingleOrDefaultAsync(ct);
        if (addressRow is null)
            return Array.Empty<MatchingCandidate>();
        var address = new AddressMatchData(addressRow.District, addressRow.City, addressRow.Location);

        var profiles = await peopleDb.CaregiverProfiles.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "APPROVED"
                && x.AvailabilityStatus == "ONLINE")
            .ToListAsync(ct);

        if (profiles.Count == 0)
            return Array.Empty<MatchingCandidate>();

        var caregiverIds = profiles.Select(x => x.Id).ToArray();
        var caregiversWithSlots = (await peopleDb.CaregiverAvailabilities.AsNoTracking()
            .Where(x => caregiverIds.Contains(x.CaregiverId))
            .Select(x => x.CaregiverId)
            .Distinct()
            .ToListAsync(ct)).ToHashSet();

        var availability = await peopleDb.CaregiverAvailabilities.AsNoTracking()
            .Where(x => caregiverIds.Contains(x.CaregiverId)
                && x.StartAt < booking.ScheduledEnd
                && x.EndAt > booking.ScheduledStart)
            .ToListAsync(ct);
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
        var candidates = new List<EligibleCandidate>();

        foreach (var profile in profiles)
        {
            if (rejected.Contains(profile.Id))
                continue;

            var profileAvailability = availability.Where(x => x.CaregiverId == profile.Id).ToList();
            var hasConfiguredSlots = caregiversWithSlots.Contains(profile.Id);
            if (!IsEligible(profile, booking, address, hasConfiguredSlots, profileAvailability,
                    conflicts.Where(x => x.CaregiverId == profile.Id)
                        .Select(x => new BookingWindow(x.BookingId, x.ScheduledStart, x.ScheduledEnd))))
                continue;

            var straightLineDistance = DistanceMeters(profile.ServiceCenterLocation, address.Location);
            var skillMatch = SkillMatchScore(requiredSkills, ParseSkills(profile.Skills));
            var ratingScore = profile.RatingCount == 0
                ? 0.5m
                : Math.Clamp(profile.RatingAvg / 5m, 0m, 1m);
            var experienceScore = Math.Clamp((profile.YearsOfExperience ?? 0) / 10m, 0m, 1m);

            candidates.Add(new EligibleCandidate(
                profile.Id,
                PointToGeoPoint(profile.ServiceCenterLocation),
                straightLineDistance,
                ratingScore,
                skillMatch,
                experienceScore));
        }

        if (candidates.Count == 0 || address.Location is null)
            return Array.Empty<MatchingCandidate>();

        var routableShortlist = candidates
            .Where(x => x.Origin is not null)
            .OrderBy(x => x.StraightLineDistanceMeters ?? int.MaxValue)
            .Take(Math.Max(1, RoutingConfig.CandidateLimit))
            .ToArray();
        if (routableShortlist.Length == 0)
            return Array.Empty<MatchingCandidate>();

        var destination = PointToGeoPoint(address.Location);
        if (destination is null)
            return Array.Empty<MatchingCandidate>();

        var routes = await routeMatrix.CalculateAsync(
            routableShortlist.Select(x => x.Origin!).ToArray(),
            destination,
            ct);
        var routeByOrigin = routes.ToDictionary(x => x.OriginIndex);

        var scored = routableShortlist
            .Select((candidate, index) =>
            {
                routeByOrigin.TryGetValue(index, out var route);
                return route?.IsRoutable == true
                    ? ToScoredCandidate(candidate, route)
                    : null;
            })
            .OfType<ScoredCandidate>()
            .ToArray();

        return scored
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.DurationSeconds ?? int.MaxValue)
            .ThenBy(x => x.DistanceMeters ?? int.MaxValue)
            .Select((x, index) => new MatchingCandidate(
                x.CaregiverId, index + 1, decimal.Round(x.Score, 4), x.DistanceMeters,
                x.ScoreBreakdown))
            .ToArray();
    }

    public async Task<IReadOnlyList<Guid>> GetOpenBookingIdsForCaregiverAsync(
        Guid caregiverId, CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var openBookingsQuery = bookingDb.Bookings.AsNoTracking()
            .Where(x => x.CaregiverId == null && x.Status == BookingStatus.Confirmed);

        var activeOfferIds = await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.CaregiverId == caregiverId
                && (x.Status == "OFFERED" || x.Status == "SUGGESTED")
                && (x.ExpiresAt == null || x.ExpiresAt > now))
            .Join(openBookingsQuery, x => x.BookingId, x => x.Id, (_, booking) => booking.Id)
            .ToListAsync(ct);

        var profile = await peopleDb.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == caregiverId && x.DeletedAt == null, ct);
        if (profile is null || profile.KycStatus != "APPROVED" || profile.AvailabilityStatus != "ONLINE")
            return activeOfferIds.Distinct().ToArray();

        var legacyOpenBookings = await openBookingsQuery
            .Where(x => !bookingDb.BookingAssignments.Any(a => a.BookingId == x.Id))
            .ToListAsync(ct);
        if (legacyOpenBookings.Count == 0)
            return activeOfferIds.Distinct().ToArray();

        var addressIds = legacyOpenBookings.Select(x => x.AddressId).Distinct().ToArray();
        var addresses = await catalogDb.Addresses.AsNoTracking()
            .Where(x => addressIds.Contains(x.Id))
            .Select(x => new { x.Id, x.District, x.City, x.Location })
            .ToDictionaryAsync(x => x.Id, x => new AddressMatchData(x.District, x.City, x.Location), ct);

        var minStart = legacyOpenBookings.Min(x => x.ScheduledStart);
        var maxEnd = legacyOpenBookings.Max(x => x.ScheduledEnd);
        var hasConfiguredSlots = await peopleDb.CaregiverAvailabilities.AsNoTracking()
            .AnyAsync(x => x.CaregiverId == caregiverId, ct);
        var availability = await peopleDb.CaregiverAvailabilities.AsNoTracking()
            .Where(x => x.CaregiverId == caregiverId && x.StartAt < maxEnd && x.EndAt > minStart)
            .ToListAsync(ct);
        var conflicts = await bookingDb.Bookings.AsNoTracking()
            .Where(x => x.CaregiverId == caregiverId
                && x.Status != BookingStatus.Completed
                && x.Status != BookingStatus.Cancelled
                && x.Status != BookingStatus.Refunded
                && x.Status != BookingStatus.MatchingFailed
                && x.ScheduledStart < maxEnd
                && x.ScheduledEnd > minStart)
            .Select(x => new BookingWindow(x.Id, x.ScheduledStart, x.ScheduledEnd))
            .ToListAsync(ct);

        var fallbackIds = legacyOpenBookings
            .Where(x => addresses.TryGetValue(x.AddressId, out var address)
                && IsEligible(profile, x, address, hasConfiguredSlots,
                    availability.Where(a => a.StartAt < x.ScheduledEnd && a.EndAt > x.ScheduledStart).ToList(),
                    conflicts))
            .Select(x => x.Id);

        return activeOfferIds.Concat(fallbackIds).Distinct().ToArray();
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

        var existing = await bookingDb.BookingAssignments
            .Where(x => x.BookingId == bookingId)
            .ToListAsync(ct);
        var alreadyAssigned = existing.Select(x => x.CaregiverId).ToHashSet();
        var now = DateTimeOffset.UtcNow;
        var selected = eligible.Where(x => !alreadyAssigned.Contains(x.CaregiverId))
            .Take(Math.Max(1, Config.InitialOfferCount)).ToArray();
        if (selected.Length == 0)
        {
            await MarkMatchingFailedAsync(booking, ct);
            return Array.Empty<MatchingCandidate>();
        }

        var expiresAt = now.AddMinutes(Math.Max(1, Config.OfferLifetimeMinutes));
        foreach (var candidate in selected)
        {
            bookingDb.BookingAssignments.Add(BookingAssignment.CreateOffered(
                bookingId, candidate.CaregiverId, candidate.Rank, candidate.DistanceMeters,
                candidate.Score, JsonSerializer.Serialize(candidate.ScoreBreakdown), now, expiresAt));
        }

        await bookingDb.SaveChangesAsync(ct);

        foreach (var candidate in selected)
        {
            var userId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(candidate.CaregiverId, ct);
            if (userId is null) continue;
            await notifications.NotifyAsync(new UserNotificationMessage(
                userId.Value,
                "BOOKING_OFFER",
                "Bạn có ca chăm sóc phù hợp",
                "Một khách hàng đang cần bạn xác nhận ca chăm sóc.",
                new Dictionary<string, string>
                {
                    ["bookingId"] = bookingId.ToString(),
                    ["status"] = "confirmed",
                    ["deepLink"] = $"/bookings/{bookingId}"
                }), ct);
        }

        logger.LogInformation("Created {Count} caregiver offers for booking {BookingId}.",
            selected.Length, bookingId);
        return selected;
    }

    public async Task<int> ExpandExpiredOffersAsync(
        CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var bookingIds = await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.Status == "OFFERED" && x.ExpiresAt != null && x.ExpiresAt <= now)
            .Select(x => x.BookingId)
            .Distinct()
            .ToListAsync(ct);
        var expanded = 0;

        foreach (var bookingId in bookingIds)
        {
            var booking = await bookingDb.Bookings.SingleOrDefaultAsync(
                x => x.Id == bookingId && x.Status == BookingStatus.Confirmed && x.CaregiverId == null, ct);
            if (booking is null) continue;

            var hasActiveOffer = await bookingDb.BookingAssignments.AsNoTracking().AnyAsync(x =>
                x.BookingId == bookingId && x.Status == "OFFERED"
                && x.ExpiresAt != null && x.ExpiresAt > now, ct);
            if (hasActiveOffer) continue;

            var expired = await bookingDb.BookingAssignments
                .Where(x => x.BookingId == bookingId && x.Status == "OFFERED"
                    && x.ExpiresAt != null && x.ExpiresAt <= now)
                .ToListAsync(ct);
            foreach (var assignment in expired)
                assignment.MarkExpired();
            await bookingDb.SaveChangesAsync(ct);

            var offers = await OfferExpansionBatchAsync(bookingId, ct);
            expanded += offers.Count;
        }

        return expanded;
    }

    private async Task<IReadOnlyList<MatchingCandidate>> OfferExpansionBatchAsync(
        Guid bookingId, CancellationToken ct)
    {
        var booking = await bookingDb.Bookings.SingleOrDefaultAsync(x =>
            x.Id == bookingId && x.Status == BookingStatus.Confirmed && x.CaregiverId == null, ct);
        if (booking is null) return Array.Empty<MatchingCandidate>();

        var eligible = await GetEligibleCaregiversAsync(bookingId, ct);
        var existingIds = (await bookingDb.BookingAssignments.AsNoTracking()
            .Where(x => x.BookingId == bookingId)
            .Select(x => x.CaregiverId)
            .ToListAsync(ct)).ToHashSet();
        var selected = eligible.Where(x => !existingIds.Contains(x.CaregiverId))
            .Take(Math.Max(1, Config.ExpansionOfferCount)).ToArray();
        if (selected.Length == 0)
        {
            await MarkMatchingFailedAsync(booking, ct);
            return Array.Empty<MatchingCandidate>();
        }

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
        logger.LogInformation("Expanded {Count} caregiver offers for booking {BookingId}.",
            selected.Length, bookingId);
        return selected;
    }

    private async Task MarkMatchingFailedAsync(Booking booking, CancellationToken ct)
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
            booking.CustomerId,
            "MATCHING_FAILED",
            "Chưa tìm thấy người chăm sóc phù hợp",
            "Hiện chưa có người chăm sóc phù hợp nhận ca này. Bạn có thể đổi lịch hoặc chọn thủ công.",
            new Dictionary<string, string>
            {
                ["bookingId"] = booking.Id.ToString(),
                ["status"] = "matching_failed",
                ["deepLink"] = $"/bookings/{booking.Id}"
            }), ct);
        logger.LogWarning("Marked booking {BookingId} as matching failed because no caregivers remain.",
            booking.Id);
    }

    private async Task NotifyOfferAsync(Guid bookingId, MatchingCandidate candidate,
        CancellationToken ct)
    {
        var userId = await peopleLookup.GetUserIdByCaregiverProfileIdAsync(candidate.CaregiverId, ct);
        if (userId is null) return;
        await notifications.NotifyAsync(new UserNotificationMessage(
            userId.Value,
            "BOOKING_OFFER",
            "Bạn có ca chăm sóc phù hợp",
            "Một khách hàng đang cần bạn xác nhận ca chăm sóc.",
            new Dictionary<string, string>
            {
                ["bookingId"] = bookingId.ToString(),
                ["status"] = "confirmed",
                ["deepLink"] = $"/bookings/{bookingId}"
            }), ct);
    }

    internal static bool HasAvailability(bool hasConfiguredSlots, bool allowWithoutSlots,
        IReadOnlyCollection<CaregiverAvailability> slots,
        DateTimeOffset start, DateTimeOffset end)
    {
        if (!hasConfiguredSlots)
            return allowWithoutSlots;

        var hasBlockedSlot = slots.Any(x => x.Status == "BLOCKED" && x.StartAt < end && x.EndAt > start);
        if (hasBlockedSlot)
            return false;

        return slots.Any(x => x.Status == "AVAILABLE" && x.StartAt <= start && x.EndAt >= end);
    }

    private bool IsEligible(CaregiverProfile profile, Booking booking, AddressMatchData address,
        bool hasConfiguredSlots,
        IReadOnlyCollection<CaregiverAvailability> availability,
        IEnumerable<BookingWindow> conflicts)
    {
        if (profile.DeletedAt is not null || profile.KycStatus != "APPROVED"
            || profile.AvailabilityStatus != "ONLINE")
            return false;

        if (conflicts.Any(x => x.BookingId != booking.Id
            && x.ScheduledStart < booking.ScheduledEnd
            && x.ScheduledEnd > booking.ScheduledStart))
            return false;

        if (!HasAvailability(hasConfiguredSlots, Config.AllowCaregiversWithoutAvailabilitySlots, availability, booking.ScheduledStart, booking.ScheduledEnd))
            return false;

        var distance = DistanceMeters(profile.ServiceCenterLocation, address.Location);
        if (!AreaMatches(profile, address, distance, Config.MaxDistanceMeters))
            return false;

        var requiredSkills = ParseSkills(booking.RequiredSkills);
        var skillMatch = SkillMatchScore(requiredSkills, ParseSkills(profile.Skills));
        if (requiredSkills.Count > 0 && skillMatch < 1m)
            return false;

        return profile.RatingCount <= 0 || profile.RatingAvg >= Config.MinimumRating;
    }

    internal static bool AreaMatches(CaregiverProfile profile, AddressMatchData address, int? distance, int maxDistanceMeters)
    {
        if (distance is { } meters)
            return meters <= (profile.ServiceRadiusMeters ?? maxDistanceMeters);

        return AreaMatchesByDistrict(profile, address);
    }

    internal static bool AreaMatchesByDistrict(CaregiverProfile profile, AddressMatchData address)
    {
        if (string.IsNullOrWhiteSpace(profile.ServiceDistrict) || string.IsNullOrWhiteSpace(address.District))
            return false;
        if (string.IsNullOrWhiteSpace(profile.ServiceCity) || string.IsNullOrWhiteSpace(address.City))
            return false;

        return Normalize(profile.ServiceDistrict) == Normalize(address.District)
            && Normalize(profile.ServiceCity) == Normalize(address.City);
    }

    internal static int? DistanceMeters(Point? from, Point? to)
    {
        if (from is null || to is null) return null;
        const double earthRadius = 6371000d;
        var lat1 = from.Y * Math.PI / 180d;
        var lat2 = to.Y * Math.PI / 180d;
        var deltaLat = (to.Y - from.Y) * Math.PI / 180d;
        var deltaLng = (to.X - from.X) * Math.PI / 180d;
        var a = Math.Sin(deltaLat / 2) * Math.Sin(deltaLat / 2)
            + Math.Cos(lat1) * Math.Cos(lat2)
            * Math.Sin(deltaLng / 2) * Math.Sin(deltaLng / 2);
        return (int)Math.Round(earthRadius * 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a)));
    }

    internal static decimal SkillMatchScore(IReadOnlySet<string> required, IReadOnlySet<string> actual)
    {
        if (required.Count == 0) return 1m;
        var matched = required.Count(skill => actual.Any(candidate =>
            candidate.Contains(skill, StringComparison.OrdinalIgnoreCase)
            || skill.Contains(candidate, StringComparison.OrdinalIgnoreCase)));
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
                using var doc = JsonDocument.Parse(trimmed);
                if (doc.RootElement.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in doc.RootElement.EnumerateArray())
                    {
                        string? value = item.ValueKind == JsonValueKind.String
                            ? item.GetString()
                            : null;
                        if (value is null && item.ValueKind == JsonValueKind.Object)
                        {
                            foreach (var property in item.EnumerateObject())
                            {
                                if (!property.NameEquals("name") && !property.NameEquals("code")
                                    && !property.NameEquals("label"))
                                    continue;
                                if (property.Value.ValueKind == JsonValueKind.String)
                                    value = property.Value.GetString();
                                break;
                            }
                        }
                        if (!string.IsNullOrWhiteSpace(value)) skills.Add(Normalize(value));
                    }
                    return skills;
                }
            }
        }
        catch (JsonException)
        {
            // Fall back to delimited text parsing below.
        }

        var tokens = trimmed.Split(new[] { ',', ';', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var token in tokens)
        {
            var clean = token.Trim().Trim('"', '\'', '[', ']');
            if (!string.IsNullOrWhiteSpace(clean))
                skills.Add(Normalize(clean));
        }

        return skills;
    }

    internal static string Normalize(string value) =>
        string.Join(' ', value.Trim().ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries));

    private static bool CanRankCaregiversForStatus(BookingStatus status, bool allowPrePayment) =>
        status == BookingStatus.Confirmed ||
        (allowPrePayment && status is BookingStatus.Draft or BookingStatus.PendingPayment);

    private ScoredCandidate ToScoredCandidate(EligibleCandidate candidate, RouteMatrixItem route)
    {
        var distanceScore = route.DistanceMeters is null
            ? 0m
            : Math.Clamp(1m - (decimal)route.DistanceMeters.Value / Config.MaxDistanceMeters, 0m, 1m);
        var scoreBreakdown = new Dictionary<string, decimal>
        {
            ["distance"] = distanceScore,
            ["rating"] = candidate.RatingScore,
            ["skillMatch"] = candidate.SkillMatchScore,
            ["experience"] = candidate.ExperienceScore
        };
        if (route.DurationSeconds is { } durationSeconds)
            scoreBreakdown["travelTimeMinutes"] = decimal.Round(durationSeconds / 60m, 2);

        var score = distanceScore * Config.Weights.Distance
            + candidate.RatingScore * Config.Weights.Rating
            + candidate.SkillMatchScore * Config.Weights.SkillMatch
            + candidate.ExperienceScore * Config.Weights.Experience;

        return new ScoredCandidate(candidate.CaregiverId, score, route.DistanceMeters,
            route.DurationSeconds, scoreBreakdown);
    }

    private static GeoPoint? PointToGeoPoint(Point? point) =>
        point is null ? null : new GeoPoint(point.Y, point.X);

    internal sealed record AddressMatchData(string? District, string? City, Point? Location);
    private sealed record CaregiverBookingWindow(
        Guid CaregiverId, Guid BookingId, DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
    private sealed record BookingWindow(Guid BookingId, DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
    private sealed record EligibleCandidate(Guid CaregiverId, GeoPoint? Origin,
        int? StraightLineDistanceMeters, decimal RatingScore, decimal SkillMatchScore,
        decimal ExperienceScore);
    private sealed record ScoredCandidate(Guid CaregiverId, decimal Score, int? DistanceMeters,
        int? DurationSeconds,
        IReadOnlyDictionary<string, decimal> ScoreBreakdown);
}
