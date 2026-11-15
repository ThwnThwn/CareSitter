using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class MealHealthFingerprintTests
{
    [Fact]
    public void Only_liked_disliked_foods_and_revision_are_excluded()
    {
        var source = new BeneficiaryHealthSnapshot(Guid.NewGuid(), 1, null, "reported_none", null,
            "Keep", null, null, null, null, null, null, null);
        var preferences = source with { Revision = 2, HealthHistory = JsonSerializer.SerializeToElement(new {
            nutrition = new { schemaVersion = 1, preferredFoods = "Cá", dislikedFoods = "Trứng" } }) };
        Assert.Equal(MealHealthFingerprint.For(source), MealHealthFingerprint.For(preferences));
        Assert.NotEqual(MealHealthFingerprint.For(source), MealHealthFingerprint.For(preferences with { GeneralNote = "Changed" }));
        Assert.NotEqual(MealHealthFingerprint.For(source), MealHealthFingerprint.For(preferences with { Allergies = JsonSerializer.SerializeToElement(new[] { "Tôm" }) }));
        Assert.NotEqual(MealHealthFingerprint.For(source), MealHealthFingerprint.For(preferences with { HealthHistory = JsonSerializer.SerializeToElement(new {
            nutrition = new { schemaVersion = 1, swallowingStatus = "difficulty", preferredFoods = "Cá" } }) }));
    }
}
