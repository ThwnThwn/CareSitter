using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Controllers;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using System.Reflection;

namespace CareSitter.IntegrationTests;

public sealed class ConsultationRequestTests
{
    private static readonly DateTime Now = new(2026, 10, 12, 3, 0, 0, DateTimeKind.Utc);
    [Fact]
    public void Normalizes_contact_without_turning_the_request_into_a_booking()
    {
        var result = ConsultationRequest.Create(Guid.NewGuid(), "  Gia đình A ", "+84 912 345 678",
            "elderly_care", new DateOnly(2026, 10, 13), 4, " ", "  Tư vấn buổi sáng ", true, Now);
        Assert.True(result.IsSuccess);
        Assert.Equal("0912345678", result.Value.Phone);
        Assert.Equal("Gia đình A", result.Value.ContactName);
        Assert.Null(result.Value.CaregiverPreference);
        Assert.Equal(Now, result.Value.ConsentAt);
    }

    [Theory]
    [InlineData("", true, 4, "consultation.phone")]
    [InlineData("0912345678", false, 4, "consultation.consent")]
    [InlineData("0912345678", true, 3, "consultation.hours")]
    public void Rejects_invalid_contact_consent_and_duration(string phone, bool consent,
        int hours, string code)
    {
        var result = ConsultationRequest.Create(Guid.NewGuid(), "Gia đình A", phone,
            "elderly_care", new DateOnly(2026, 10, 13), hours, null, null, consent, Now);
        Assert.True(result.IsFailure);
        Assert.Equal(code, result.Error.Code);
    }

    [Fact]
    public void Rejects_past_date_in_Vietnam_even_before_UTC_midnight()
    {
        var now = new DateTime(2026, 10, 12, 18, 0, 0, DateTimeKind.Utc);
        var result = ConsultationRequest.Create(Guid.NewGuid(), "Gia đình A", "0912345678",
            "elderly_care", new DateOnly(2026, 10, 12), 4, null, null, true, now);
        Assert.Equal("consultation.date", result.Value.ValidateNewSubmission().Error.Code);
    }

    [Fact]
    public void Public_creation_is_rate_limited_and_personal_data_listing_requires_admin()
    {
        var create = typeof(ConsultationRequestsController).GetMethod("Create")!;
        Assert.NotNull(create.GetCustomAttribute<AllowAnonymousAttribute>());
        Assert.Equal("consultation-request", create.GetCustomAttribute<EnableRateLimitingAttribute>()!.PolicyName);
        var list = typeof(ConsultationRequestsController).GetMethod("List")!;
        Assert.Equal("ADMIN", list.GetCustomAttribute<AuthorizeAttribute>()!.Roles);
        Assert.Null(list.GetCustomAttribute<AllowAnonymousAttribute>());
    }
}
