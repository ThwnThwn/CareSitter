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
}
