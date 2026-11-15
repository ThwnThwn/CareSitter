using System.Text.Json;
using CareSitter.ApiHost.Nutrition;
using CareSitter.Nutrition.Grpc.V1;

namespace CareSitter.IntegrationTests;

public sealed class MealPlanSnapshotReaderTests
{
    [Fact]
    public async Task Snapshot_whitelists_preparation_data_without_health_profile_or_ai_explanation()
    {
        var plan = Guid.NewGuid(); var beneficiary = Guid.NewGuid(); var recipe = Guid.NewGuid();
        var data = JsonSerializer.SerializeToElement(new { plannedDate = "2026-11-14",
            decision = new { conditions = new[] { "private-condition" } },
            recommendationTrace = new { explanation = "private-explanation" },
            meals = new[] { new { versionId = recipe, name = "Cháo", mealType = "lunch", servings = 1,
                ingredients = new[] { new { name = "Gạo", amount = 50, unit = "g", privateCode = "hidden" } },
                preparationSteps = new[] { "Nấu chín" }, allergens = Array.Empty<string>() } } });
        var gateway = new Gateway(new(200, new NutritionResourceResponse(plan, beneficiary, 1, "saved", data, DateTimeOffset.UtcNow)));
        var result = await new MealPlanSnapshotReader(gateway).ReadAsync(beneficiary, plan, default);
        Assert.True(result.IsSuccess, result.Error.Message);
        var json = JsonSerializer.Serialize(result.Value);
        Assert.Contains("Gạo", JsonSerializer.Serialize(result.Value, new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }));
        Assert.DoesNotContain("private", json); Assert.DoesNotContain("hidden", json);
        Assert.Equal(ResourceKind.Plan, gateway.Request!.Kind);
        Assert.Equal(beneficiary.ToString(), gateway.Request.BeneficiaryId);
    }
    [Theory]
    [InlineData("stale")]
    [InlineData("queued")]
    public async Task Stale_or_unsaved_plan_is_never_shared(string status)
    {
        var id = Guid.NewGuid(); var beneficiary = Guid.NewGuid();
        var gateway = new Gateway(new(200, new NutritionResourceResponse(id, beneficiary, 1, status,
            JsonSerializer.SerializeToElement(new { }), DateTimeOffset.UtcNow)));
        var result = await new MealPlanSnapshotReader(gateway).ReadAsync(beneficiary, id, default);
        Assert.Equal("booking.meals.plan_stale", result.Error.Code);
    }
    [Fact]
    public async Task Malformed_meal_array_returns_controlled_error()
    {
        var id = Guid.NewGuid(); var beneficiary = Guid.NewGuid();
        var gateway = new Gateway(new(200, new NutritionResourceResponse(id, beneficiary, 1, "saved",
            JsonSerializer.SerializeToElement(new { plannedDate = "2026-11-14", meals = new object?[] { null } }), DateTimeOffset.UtcNow)));
        var result = await new MealPlanSnapshotReader(gateway).ReadAsync(beneficiary, id, default);
        Assert.Equal("booking.meals.invalid_plan", result.Error.Code);
    }
    private sealed class Gateway(NutritionGatewayResponse response) : INutritionGateway
    {
        public ResourceRequest? Request { get; private set; }
        public Task<NutritionGatewayResponse> ReadAsync(ResourceRequest request, CancellationToken ct)
        { Request = request; return Task.FromResult(response); }
        public Task<NutritionGatewayResponse> CapabilitiesAsync(CancellationToken ct) => throw new NotSupportedException();
        public Task<NutritionGatewayResponse> ExecuteAsync(CommandRequest request, CancellationToken ct) => throw new NotSupportedException();
        public Task<NutritionGatewayResponse> PlansAsync(BeneficiaryRequest request, CancellationToken ct) => throw new NotSupportedException();
        public Task<NutritionGatewayResponse> ReplacementsAsync(ReplacementOptionsRequest request, CancellationToken ct) => throw new NotSupportedException();
        public Task<NutritionGatewayResponse> KnowledgeAsync(string query, CancellationToken ct, bool localDemo = false,
            bool generalKnowledge = false) => throw new NotSupportedException();
    }

    [Fact]
    public async Task Stale_owned_plan_can_supply_historical_feedback_but_cannot_be_shared()
    {
        var id = Guid.NewGuid(); var beneficiary = Guid.NewGuid();
        var data = JsonSerializer.SerializeToElement(new { plannedDate = "2026-11-14", meals = new[] {
            new { versionId = Guid.NewGuid(), name = "Cháo", mealType = "lunch", servings = 1,
                ingredients = new[] { new { name = "Gạo", amount = 50, unit = "g" } },
                preparationSteps = new[] { "Nấu chín" }, allergens = Array.Empty<string>() } } });
        var reader = new MealPlanSnapshotReader(new Gateway(new(200,
            new NutritionResourceResponse(id, beneficiary, 1, "stale", data, DateTimeOffset.UtcNow))));
        Assert.True((await reader.ReadForFeedbackAsync(beneficiary, id, default)).IsSuccess);
        Assert.Equal("booking.meals.plan_stale", (await reader.ReadAsync(beneficiary, id, default)).Error.Code);
    }
}
