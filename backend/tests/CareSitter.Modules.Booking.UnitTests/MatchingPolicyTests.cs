using CareSitter.Contracts.Services;
using CareSitter.Contracts.Services.Routing;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Matching;
using CareSitter.Modules.Booking.Domain;
using static CareSitter.Modules.Booking.Application.Matching.MatchingPolicy;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class MatchingPolicyTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.Parse("2026-10-04T00:00:00Z");
    private static MatchingCaregiverProfile Profile() => new(Guid.NewGuid(), "APPROVED", "ONLINE",
        "elderly care", "HCM", "District 1", new GeoPoint(10.8, 106.7),
        null, 4m, 10, 5, null);
    private static readonly MatchingAddress Address = new("District 1", "HCM", new GeoPoint(10.8, 106.7));
    private static Domain.Booking Booking() => Domain.Booking.Create(
        Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Now.AddHours(2), Now.AddHours(4)).Value;

    [Fact]
    public void Hard_filters_reject_unverified_offline_deleted_or_low_rated_profiles()
    {
        var profile = Profile();
        var booking = Booking();
        var options = new MatchingOptions();
        Assert.True(IsEligible(profile, booking, Address, [], options));
        Assert.False(IsEligible(profile with { KycStatus = "PENDING" }, booking, Address, [], options));
        Assert.False(IsEligible(profile with { AvailabilityStatus = "OFFLINE" }, booking, Address, [], options));
        Assert.False(IsEligible(profile with { DeletedAt = Now }, booking, Address, [], options));
        Assert.False(IsEligible(profile with { RatingAverage = 3m }, booking, Address, [], options));
        Assert.True(IsEligible(profile with { RatingCount = 0, RatingAverage = 0m }, booking, Address, [], options));
    }

    [Fact]
    public void Overlap_excludes_self_and_allows_adjacent_time_windows()
    {
        var profile = Profile();
        var booking = Booking();
        var options = new MatchingOptions();
        var window = new CaregiverBookingWindow(profile.Id, Guid.NewGuid(),
            booking.ScheduledStart, booking.ScheduledEnd);
        Assert.False(IsEligible(profile, booking, Address, [window], options));
        Assert.True(IsEligible(profile, booking, Address, [window with { BookingId = booking.Id }], options));
        Assert.True(IsEligible(profile, booking, Address,
            [window with { ScheduledStart = booking.ScheduledEnd }], options));
    }

    [Fact]
    public void Shortlist_excludes_missing_origin_and_orders_nearest_with_limit()
    {
        var far = PrepareCandidate(Profile() with { ServiceCenter = new GeoPoint(10.81, 106.7) },
            Address, ParseSkills(null));
        var near = PrepareCandidate(Profile(), Address, ParseSkills(null));
        var missing = PrepareCandidate(Profile() with { ServiceCenter = null }, Address, ParseSkills(null));
        Assert.Equal(near, Assert.Single(Shortlist([far, missing, near],
            new MatchingOptions { RouteCandidateLimit = 1 })));
    }

    [Fact]
    public void Ranking_preserves_weighted_score_rounding_and_duration_tie_break()
    {
        var options = new MatchingOptions();
        var slower = PrepareCandidate(Profile(), Address, ParseSkills("elderly care"));
        var faster = slower with { CaregiverId = Guid.NewGuid() };
        var ranked = Rank([slower, faster], [new(0, 1000, 120), new(1, 1000, 60)], options);
        Assert.Equal(faster.CaregiverId, ranked[0].CaregiverId);
        Assert.Equal(1, ranked[0].Rank);
        Assert.Equal(2, ranked[1].Rank);
        Assert.Equal(0.855m, ranked[0].Score); // .9*.35 + .8*.30 + 1*.25 + .5*.10
        Assert.Equal(1m, ranked[0].ScoreBreakdown["travelTimeMinutes"]);
    }

    [Fact]
    public void Ranking_drops_unroutable_candidates_and_uses_distance_for_equal_duration()
    {
        var options = new MatchingOptions { Weights = new MatchingWeights {
            Distance = 0, Rating = 1, SkillMatch = 0, Experience = 0 } };
        var first = PrepareCandidate(Profile(), Address, ParseSkills(null));
        var second = first with { CaregiverId = Guid.NewGuid() };
        var third = first with { CaregiverId = Guid.NewGuid() };
        var ranked = Rank([first, second, third],
            [new(0, 2000, 60), new(1, 1000, 60), new(2, null, null)], options);
        Assert.Equal(2, ranked.Count);
        Assert.Equal(second.CaregiverId, ranked[0].CaregiverId);
    }

    [Theory]
    [InlineData(BookingStatus.Confirmed, false, true)]
    [InlineData(BookingStatus.PendingPayment, false, false)]
    [InlineData(BookingStatus.PendingPayment, true, true)]
    [InlineData(BookingStatus.Draft, true, true)]
    [InlineData(BookingStatus.Cancelled, true, false)]
    public void Suggestions_do_not_bypass_booking_status(BookingStatus status, bool prepay, bool expected)
        => Assert.Equal(expected, CanRankCaregiversForStatus(status, prepay));

    [Fact]
    public void Skills_keep_legacy_json_and_delimited_matching_behavior()
    {
        var skills = ParseSkills("[{\"label\":\" Elderly  Care \"},\"DEMENTIA\"]");
        Assert.Contains("elderly care", skills);
        Assert.Contains("dementia", skills);
        Assert.Equal(0.5m, SkillMatchScore(ParseSkills("elderly care, injection"), skills));
        Assert.Equal(1m, SkillMatchScore(ParseSkills("care"), skills));
        Assert.Equal(1m, SkillMatchScore(ParseSkills(null), skills));
        Assert.Equal(0, DistanceMeters(Address.Location, Address.Location));
    }
}
