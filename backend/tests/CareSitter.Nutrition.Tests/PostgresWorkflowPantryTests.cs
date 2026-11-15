using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Tests;

public sealed partial class PostgresWorkflowTests
{
    [PostgresFact]
    public async Task Pantry_request_is_durable_retry_safe_and_preserved_in_saved_plan()
    {
        var assessment = await ConcurrentMealFixtureAsync();
        var ingredient = await _store.InOwnerScopeAsync(_owner, async session =>
            (await session.RecipesAsync(default)).First().Ingredients[0].Name, default);
        var request = (RecommendMealsCommand)Request("recommend", assessment: assessment);
        request = request with { Input = request.Input with { AvailableIngredients = [ingredient] } };
        var results = await Task.WhenAll(Handler().Handle(request, default), Handler().Handle(request, default));
        Assert.All(results, result => Assert.True(result.IsSuccess, result.Error.Message));
        Assert.Equal(results[0].Value.Id, results[1].Value.Id);
        var expected = MealPantryPolicy.Normalize([ingredient]);
        Assert.Equal(expected, NutritionJson.Read<MealPayload>(results[0].Value.Data.GetRawText()).AvailableIngredients);
        var conflict = await Handler().Handle(request with { Input = request.Input with { AvailableIngredients = ["khác nguyên liệu"] } }, default);
        Assert.Equal("nutrition.idempotency_conflict", conflict.Error.Code);
        var saved = await Handler().Handle(Request("save", results[0].Value.Id), default);
        Assert.True(saved.IsSuccess, saved.Error.Message);
        var loaded = await ReadAsync("plan", saved.Value.Id);
        Assert.Equal(expected, NutritionJson.Read<MealPayload>(loaded.Value.Data.GetRawText()).AvailableIngredients);
        Assert.True(loaded.Value.Data.GetProperty("isSavedPlan").GetBoolean());
    }
}
