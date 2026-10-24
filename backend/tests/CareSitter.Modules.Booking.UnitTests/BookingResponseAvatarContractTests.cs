using System.Text.Json;
using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingResponseAvatarContractTests
{
    [Fact]
    public void Customer_booking_contract_exposes_the_caregiver_avatar()
    {
        const string avatarUrl = "https://cdn.example/caregivers/bich-ngoc.jpg";
        var now = DateTimeOffset.UtcNow;
        var response = new BookingResponse(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            now, now.AddHours(4), null, null, null, null,
            "caregiver_accepted", 360_000, 54_000, 306_000,
            null, null, now, now,
            CaregiverAvatar: avatarUrl);

        var json = JsonSerializer.SerializeToElement(
            response,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.Equal(avatarUrl, json.GetProperty("caregiverAvatar").GetString());
    }

    [Fact]
    public void Caregiver_booking_contract_exposes_beneficiary_avatar_metadata()
    {
        const string avatarUrl = "https://cdn.example/beneficiaries/loan.jpg";
        var now = DateTimeOffset.UtcNow;
        var response = new BookingResponse(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            now, now.AddHours(4), null, null, null, null,
            "caregiver_accepted", 360_000, 54_000, 306_000,
            null, null, now, now,
            BeneficiaryGender: "female",
            BeneficiaryAvatarUrl: avatarUrl);

        var json = JsonSerializer.SerializeToElement(
            response,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));

        Assert.Equal("female", json.GetProperty("beneficiaryGender").GetString());
        Assert.Equal(avatarUrl, json.GetProperty("beneficiaryAvatarUrl").GetString());
    }
}
