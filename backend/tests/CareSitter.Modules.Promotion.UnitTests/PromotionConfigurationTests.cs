using CareSitter.Modules.Promotion.Application;
using CareSitter.Modules.Promotion.Domain;

namespace CareSitter.Modules.Promotion.UnitTests;

public sealed class PromotionConfigurationTests
{
    private static PromotionConfiguration Configuration() => new(
        " test_10 ", " Test ", " Summary ", null, " 10% ", [" Terms "],
        PromotionDiscountType.Percentage, 10, 100_000, 200_000,
        DateTimeOffset.Parse("2026-10-01T08:00:00+07:00"), DateTimeOffset.Parse("2026-11-01T08:00:00+07:00"),
        false, false, 100, 1, 0, true, [Guid.NewGuid()]);

    [Fact]
    public void Configuration_normalizes_content_and_preserves_eligibility_and_price()
    {
        var configuration = Configuration();
        var promotion = Domain.Promotion.Create(configuration).Value;
        Assert.Equal("TEST_10", promotion.Code);
        Assert.Equal("Test", promotion.Title);
        Assert.Equal("[\"Terms\"]", promotion.TermsJson);
        Assert.Equal(TimeSpan.Zero, promotion.StartsAt.Offset);
        Assert.False(promotion.IsActive);
        Assert.True(promotion.AppliesToService(configuration.EligibleServiceIds[0]));
        Assert.False(promotion.AppliesToService(Guid.NewGuid()));
        Assert.Equal(50_000, promotion.CalculateDiscount(500_000).Value);
    }

    [Theory]
    [InlineData("percentage")] [InlineData("type")] [InlineData("code")] [InlineData("window")]
    [InlineData("quota")] [InlineData("customer")] [InlineData("priority")] [InlineData("cap")]
    [InlineData("money")] [InlineData("terms")] [InlineData("services")] [InlineData("null-terms")]
    public void Configuration_rejects_invalid_campaigns(string invalid)
    {
        var valid = Configuration();
        var configuration = invalid switch
        {
            "percentage" => valid with { DiscountValue = 101 },
            "type" => valid with { DiscountType = (PromotionDiscountType)99 },
            "code" => valid with { Code = "BAD CODE" },
            "window" => valid with { EndsAt = valid.StartsAt },
            "quota" => valid with { TotalUsageLimit = 0 },
            "customer" => valid with { PerCustomerUsageLimit = 0 },
            "priority" => valid with { Priority = -1 },
            "cap" => valid with { MaxDiscountAmount = 0 },
            "money" => valid with { MinOrderAmount = long.MaxValue },
            "terms" => valid with { Terms = [new string('x', 501)] },
            "services" => valid with { EligibleServiceIds = [Guid.Empty] },
            _ => valid with { Terms = null! }
        };
        Assert.True(Domain.Promotion.Create(configuration).IsFailure);
    }

    [Fact]
    public void Failed_reconfiguration_leaves_existing_rules_unchanged()
    {
        var configuration = Configuration();
        var promotion = Domain.Promotion.Create(configuration).Value;
        Assert.True(promotion.Configure(configuration with { DiscountValue = -1 }).IsFailure);
        Assert.Equal(10, promotion.DiscountValue);
        Assert.True(promotion.HasSameBookingRules(configuration));
        Assert.False(promotion.HasSameBookingRules(configuration with { EligibleServiceIds = [] }));
    }

    [Fact]
    public void Scope_reconfiguration_removes_stale_bindings_and_allows_all_services()
    {
        var configuration = Configuration();
        var promotion = Domain.Promotion.Create(configuration).Value;
        var replacement = Guid.NewGuid();
        Assert.True(promotion.Configure(configuration with { EligibleServiceIds = [replacement] }).IsSuccess);
        Assert.False(promotion.AppliesToService(configuration.EligibleServiceIds[0]));
        Assert.True(promotion.AppliesToService(replacement));
        Assert.True(promotion.Configure(configuration with { EligibleServiceIds = [] }).IsSuccess);
        Assert.True(promotion.AppliesToService(Guid.NewGuid()));
    }

    [Fact]
    public void Write_validators_require_the_edit_token()
    {
        Assert.False(new UpdateAdminPromotionCommandValidator().Validate(
            new UpdateAdminPromotionCommand(Guid.NewGuid(), Configuration(), default)).IsValid);
        Assert.False(new SetAdminPromotionActiveCommandValidator().Validate(
            new SetAdminPromotionActiveCommand(Guid.NewGuid(), true, default)).IsValid);
        Assert.False(new DeleteAdminPromotionCommandValidator().Validate(
            new DeleteAdminPromotionCommand(Guid.NewGuid(), default)).IsValid);
    }
}
