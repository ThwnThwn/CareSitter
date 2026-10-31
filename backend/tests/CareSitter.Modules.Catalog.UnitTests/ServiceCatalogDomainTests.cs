using CareSitter.Modules.Catalog.Domain;

namespace CareSitter.Modules.Catalog.UnitTests;

public sealed class ServiceCatalogDomainTests
{
    [Theory]
    [InlineData(14)]
    [InlineData(1441)]
    public void Create_service_rejects_duration_outside_admin_contract(int durationMinutes)
    {
        var result = ServiceType.Create("COMPANION", "Đồng hành", defaultDurationMinutes: durationMinutes);

        Assert.True(result.IsFailure);
        Assert.Equal("service_type.default_duration_minutes", result.Error.Code);
    }

    [Fact]
    public void Create_service_normalizes_fields_like_update()
    {
        var result = ServiceType.Create("  companion  ", "  Đồng hành  ", "  Trò chuyện  ", 60);

        Assert.True(result.IsSuccess);
        Assert.Equal("COMPANION", result.Value.Code);
        Assert.Equal("Đồng hành", result.Value.Name);
        Assert.Equal("Trò chuyện", result.Value.Description);
    }

    [Fact]
    public void Create_service_accepts_https_image_and_rejects_an_invalid_url()
    {
        var valid = ServiceType.Create("COMPANION", "Đồng hành",
            imageUrl: " https://cdn.example.test/service.webp ");
        var invalid = ServiceType.Create("NURSING", "Điều dưỡng",
            imageUrl: "javascript:alert(1)");

        Assert.True(valid.IsSuccess);
        Assert.Equal("https://cdn.example.test/service.webp", valid.Value.ImageUrl);
        Assert.True(invalid.IsFailure);
        Assert.Equal("service_type.image_url", invalid.Error.Code);
    }

    [Fact]
    public void Create_pricing_rule_rejects_invalid_admin_values()
    {
        var result = PricingRule.Create(
            "Giá chuẩn", Guid.NewGuid(), 100_000,
            nightMultiplier: 0.5m,
            holidayMultiplier: 1.5m,
            platformFeePercent: 15m,
            disputeWindowHours: 48);

        Assert.True(result.IsFailure);
        Assert.Equal("pricing_rule.multiplier", result.Error.Code);
    }

    [Fact]
    public void Create_pricing_rule_rejects_an_invalid_effective_window()
    {
        var from = DateTimeOffset.UtcNow;
        var result = PricingRule.Create(
            "Giá chuẩn", Guid.NewGuid(), 100_000,
            effectiveFrom: from,
            effectiveTo: from);

        Assert.True(result.IsFailure);
        Assert.Equal("pricing_rule.effective_to", result.Error.Code);
    }

    [Fact]
    public void Create_session_plan_requires_exactly_one_session()
    {
        var result = ServicePlan.Create(Guid.NewGuid(), "AN_NHIEN_08", "An Nhiên 8 buổi",
            ServicePlanBillingUnits.Session, 480, 8, 6_000_000);

        Assert.True(result.IsFailure);
        Assert.Equal("service_plan.included_sessions", result.Error.Code);
    }

    [Fact]
    public void Create_session_package_requires_a_validity_period()
    {
        var result = ServicePlan.Create(Guid.NewGuid(), "AN_NHIEN_08", "An Nhiên 8 buổi",
            ServicePlanBillingUnits.SessionPackage, 480, 8, 6_000_000);

        Assert.True(result.IsFailure);
        Assert.Equal("service_plan.validity_days", result.Error.Code);
    }

    [Fact]
    public void Create_session_package_keeps_price_as_a_package_total()
    {
        var result = ServicePlan.Create(Guid.NewGuid(), " an_nhien_08 ", " An Nhiên 8 buổi ",
            ServicePlanBillingUnits.SessionPackage, 480, 8, 6_000_000,
            validityDays: 30);

        Assert.True(result.IsSuccess);
        Assert.Equal("AN_NHIEN_08", result.Value.Code);
        Assert.Equal(8, result.Value.IncludedSessions);
        Assert.Equal(6_000_000, result.Value.TotalPrice);
        Assert.Equal(30, result.Value.ValidityDays);
    }
}
