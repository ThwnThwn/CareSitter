using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application.Matching;

/// <summary>Pure matching rules; callers supply snapshots, routes and options. No IO or clock reads.</summary>
internal static class MatchingPolicy
{
    internal static bool IsEligible(
        MatchingCaregiverProfile profile,
        Domain.Booking booking,
        MatchingAddress address,
        IEnumerable<CaregiverBookingWindow> conflicts, MatchingOptions config)
    {
        if (profile.DeletedAt is not null || profile.KycStatus != "APPROVED" ||
            profile.AvailabilityStatus != "ONLINE")
            return false;
        if (conflicts.Any(x => x.BookingId != booking.Id &&
            x.ScheduledStart < booking.ScheduledEnd && x.ScheduledEnd > booking.ScheduledStart))
            return false;
        var distance = DistanceMeters(profile.ServiceCenter, address.Location);
        if (!AreaMatches(profile, address, distance, config.MaxDistanceMeters))
            return false;
        var required = ParseSkills(booking.RequiredSkills);
        if (required.Count > 0 && SkillMatchScore(required, ParseSkills(profile.Skills)) < 1m)
            return false;
        return profile.RatingCount <= 0 || profile.RatingAverage >= config.MinimumRating;
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

    internal static int? DistanceMeters(GeoPoint? from, GeoPoint? to)
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

    internal static decimal SkillMatchScore(IReadOnlySet<string> required, IReadOnlySet<string> actual)
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

    internal static bool CanRankCaregiversForStatus(BookingStatus status, bool allowPrePayment) =>
        status == BookingStatus.Confirmed ||
        (allowPrePayment && status is BookingStatus.Draft or BookingStatus.PendingPayment);

    private static ScoredCandidate Score(EligibleCandidate candidate, RouteMatrixItem route, MatchingOptions config)
    {
        var distanceScore = route.DistanceMeters is null
            ? 0m
            : Math.Clamp(1m - (decimal)route.DistanceMeters.Value / config.MaxDistanceMeters, 0m, 1m);
        var breakdown = new Dictionary<string, decimal>
        {
            ["distance"] = distanceScore,
            ["rating"] = candidate.RatingScore,
            ["skillMatch"] = candidate.SkillMatchScore,
            ["experience"] = candidate.ExperienceScore
        };
        if (route.DurationSeconds is { } seconds)
            breakdown["travelTimeMinutes"] = decimal.Round(seconds / 60m, 2);
        var score = distanceScore * config.Weights.Distance +
            candidate.RatingScore * config.Weights.Rating +
            candidate.SkillMatchScore * config.Weights.SkillMatch +
            candidate.ExperienceScore * config.Weights.Experience;
        return new ScoredCandidate(candidate.CaregiverId, score,
            route.DistanceMeters, route.DurationSeconds, breakdown);
    }

    internal sealed record CaregiverBookingWindow(
        Guid CaregiverId, Guid BookingId, DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
    internal sealed record EligibleCandidate(
        Guid CaregiverId, GeoPoint? Origin, int? StraightLineDistanceMeters,
        decimal RatingScore, decimal SkillMatchScore, decimal ExperienceScore);
    internal sealed record ScoredCandidate(
        Guid CaregiverId, decimal Score, int? DistanceMeters, int? DurationSeconds,
        IReadOnlyDictionary<string, decimal> ScoreBreakdown);

    internal static EligibleCandidate PrepareCandidate(MatchingCaregiverProfile profile,
        MatchingAddress address, IReadOnlySet<string> requiredSkills) => new(
        profile.Id, profile.ServiceCenter, DistanceMeters(profile.ServiceCenter, address.Location),
        profile.RatingCount == 0 ? 0.5m : Math.Clamp(profile.RatingAverage / 5m, 0m, 1m),
        SkillMatchScore(requiredSkills, ParseSkills(profile.Skills)),
        Math.Clamp((profile.YearsOfExperience ?? 0) / 10m, 0m, 1m));

    internal static EligibleCandidate[] Shortlist(IEnumerable<EligibleCandidate> eligible, MatchingOptions config) =>
        eligible.Where(x => x.Origin is not null)
            .OrderBy(x => x.StraightLineDistanceMeters ?? int.MaxValue)
            .Take(Math.Max(1, config.RouteCandidateLimit)).ToArray();

    internal static IReadOnlyList<MatchingCandidate> Rank(IReadOnlyList<EligibleCandidate> shortlist,
        IReadOnlyList<RouteMatrixItem> routes, MatchingOptions config)
    {
        var routeByOrigin = routes.ToDictionary(x => x.OriginIndex);
        return shortlist.Select((candidate, index) =>
            {
                routeByOrigin.TryGetValue(index, out var route);
                return route?.IsRoutable == true ? Score(candidate, route, config) : null;
            })
            .OfType<ScoredCandidate>()
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.DurationSeconds ?? int.MaxValue)
            .ThenBy(x => x.DistanceMeters ?? int.MaxValue)
            .Select((x, index) => new MatchingCandidate(
                x.CaregiverId, index + 1, decimal.Round(x.Score, 4),
                x.DistanceMeters, x.ScoreBreakdown)).ToArray();
    }
}
