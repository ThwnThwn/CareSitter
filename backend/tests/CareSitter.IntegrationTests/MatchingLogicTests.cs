using CareSitter.ApiHost.Matching;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.People.Domain;
using Xunit;

namespace CareSitter.IntegrationTests;

public class MatchingLogicTests
{
    [Theory]
    [InlineData("ONLINE", "ONLINE")]
    [InlineData("offline", "OFFLINE")]
    [InlineData(" Busy ", "BUSY")]
    public void SetAvailabilityStatus_WithValidStatuses_ShouldSucceed(string input, string expected)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var profile = CaregiverProfile.Create(userId).Value;

        // Act
        var result = profile.SetAvailabilityStatus(input);

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal(expected, profile.AvailabilityStatus);
    }

    [Theory]
    [InlineData("INVALID")]
    [InlineData("")]
    [InlineData(null)]
    public void SetAvailabilityStatus_WithInvalidStatuses_ShouldFail(string? input)
    {
        // Arrange
        var userId = Guid.NewGuid();
        var profile = CaregiverProfile.Create(userId).Value;

        // Act
        var result = profile.SetAvailabilityStatus(input!);

        // Assert
        Assert.True(result.IsFailure);
        Assert.Equal("caregiver.availability_status", result.Error.Code);
    }

    [Fact]
    public void MatchingWeights_ShouldSumToOne()
    {
        // Arrange
        var options = new MatchingOptions();

        // Act
        var totalWeight = options.Weights.Distance
            + options.Weights.Rating
            + options.Weights.SkillMatch
            + options.Weights.Experience;

        // Assert
        Assert.Equal(1.00m, totalWeight);
    }

    [Fact]
    public void Booking_MarkMatchingFailed_WhenConfirmedWithoutCaregiver_ShouldSucceed()
    {
        // Arrange
        var booking = Booking.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            DateTimeOffset.UtcNow.AddHours(2), DateTimeOffset.UtcNow.AddHours(4)).Value;
        booking.TransitionTo(BookingStatus.PendingPayment);
        booking.ConfirmPayment(); // Moves from PendingPayment -> Confirmed

        // Act
        var result = booking.MarkMatchingFailed();

        // Assert
        Assert.True(result.IsSuccess);
        Assert.Equal(BookingStatus.MatchingFailed, booking.Status);
    }

    [Fact]
    public void BookingAssignment_MarkExpired_WhenOffered_ShouldTransitionToExpired()
    {
        // Arrange
        var bookingId = Guid.NewGuid();
        var caregiverId = Guid.NewGuid();
        var assignment = BookingAssignment.CreateOffered(
            bookingId, caregiverId, 1, 1500, 0.85m, "{}",
            DateTimeOffset.UtcNow, DateTimeOffset.UtcNow.AddMinutes(10));

        // Act
        assignment.MarkExpired();

        // Assert
        Assert.Equal("EXPIRED", assignment.Status);
    }

    [Fact]
    public void AreaMatches_WithGpsOutsideRadius_ShouldReturnFalseEvenIfSameDistrict()
    {
        // Arrange
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        profile.UpdateProfile(serviceDistrict: "Bình Chánh", serviceCity: "Hồ Chí Minh");
        var address = new MatchingService.AddressMatchData("Bình Chánh", "Hồ Chí Minh", null);

        // Act: distance is 15km, but max distance is 10km (and profile default radius)
        var result = MatchingService.AreaMatches(profile, address, distance: 15000, maxDistanceMeters: 10000);

        // Assert: MUST return false despite matching district because GPS distance exceeds radius!
        Assert.False(result);
    }

    [Fact]
    public void AreaMatches_WithGpsWithinRadius_ShouldReturnTrue()
    {
        // Arrange
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        profile.UpdateProfile(serviceDistrict: "Bình Thạnh", serviceCity: "Hồ Chí Minh");
        var address = new MatchingService.AddressMatchData("Quận 1", "Hồ Chí Minh", null);

        // Act: distance 3km within 10km radius
        var result = MatchingService.AreaMatches(profile, address, distance: 3000, maxDistanceMeters: 10000);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void AreaMatches_WithoutGps_DifferentCitySameDistrict_ShouldReturnFalse()
    {
        // Arrange: Huyện Châu Thành ở Bến Tre vs Tiền Giang
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        profile.UpdateProfile(serviceDistrict: "Châu Thành", serviceCity: "Bến Tre");
        var address = new MatchingService.AddressMatchData("Châu Thành", "Tiền Giang", null);

        // Act
        var result = MatchingService.AreaMatches(profile, address, distance: null, maxDistanceMeters: 10000);

        // Assert: MUST return false because cities are different!
        Assert.False(result);
    }

    [Fact]
    public void AreaMatches_WithoutGps_MissingCity_ShouldReturnFalse()
    {
        // Arrange: Profile lacks city
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        profile.UpdateProfile(serviceDistrict: "Châu Thành", serviceCity: null);
        var address = new MatchingService.AddressMatchData("Châu Thành", "Bến Tre", null);

        // Act
        var result = MatchingService.AreaMatches(profile, address, distance: null, maxDistanceMeters: 10000);

        // Assert: MUST return false when city is missing
        Assert.False(result);
    }

    [Fact]
    public void AreaMatches_WithoutGps_SameCityAndDistrict_ShouldReturnTrue()
    {
        // Arrange
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        profile.UpdateProfile(serviceDistrict: "Quận 1", serviceCity: "Hồ Chí Minh");
        var address = new MatchingService.AddressMatchData("Quận 1", "Hồ Chí Minh", null);

        // Act
        var result = MatchingService.AreaMatches(profile, address, distance: null, maxDistanceMeters: 10000);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public void ParseSkills_WithDelimitedString_ShouldParseAllTokens()
    {
        // Arrange
        var raw = "tiêm thuốc, thay băng; xoa bóp";

        // Act
        var skills = MatchingService.ParseSkills(raw);

        // Assert
        Assert.Equal(3, skills.Count);
        Assert.Contains("tiêm thuốc", skills);
        Assert.Contains("thay băng", skills);
        Assert.Contains("xoa bóp", skills);
    }

    [Fact]
    public void ParseSkills_WithJsonArray_ShouldParseAllTokens()
    {
        // Arrange
        var raw = "[{\"name\":\"Elderly Care\"}, {\"code\":\"DEMENTIA\"}]";

        // Act
        var skills = MatchingService.ParseSkills(raw);

        // Assert
        Assert.Equal(2, skills.Count);
        Assert.Contains("elderly care", skills);
        Assert.Contains("dementia", skills);
    }
}
