using System.Text.Json;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class CatalogRevisionAndReplacementTests
{
    [Fact]
    public async Task Catalog_revision_change_marks_get_list_and_replay_stale_without_changing_saved_payload()
    {
        var fixture = new Fixture();
        var request = new RecommendMealsCommand(fixture.Source.BeneficiaryId,
            new NutritionWriteInput(1, Guid.NewGuid(), fixture.Assessment.Id));
        var recommendation = fixture.Recommendation with
        { IdempotencyKey = request.IdempotencyKey, Fingerprint = NutritionRequestFingerprint.For(request) };
        fixture.Session.Resources["recommendation"] = recommendation;
        var save = new SaveMealPlanCommand(fixture.Source.BeneficiaryId, recommendation.Id,
            new NutritionWriteInput(1, Guid.NewGuid()));
        fixture.Session.Resources["plan"] = fixture.Session.Resources["plan"] with
        { IdempotencyKey = save.IdempotencyKey, Fingerprint = NutritionRequestFingerprint.For(save) };
        var scope = new NutritionWriteScope(fixture, fixture, fixture, fixture);
        var queries = new NutritionResourceQueryHandler(fixture, fixture, fixture, fixture);
        foreach (var revision in new long[] { 7, 8 })
        {
            fixture.Session.Revision = revision;
            var expected = revision == 7 ? "suggested" : "stale";
            foreach (var kind in new[] { "recommendation", "plan" })
            {
                var original = fixture.Session.Resources[kind];
                var get = await queries.Handle(new NutritionResourceQuery(kind, fixture.Source.BeneficiaryId, original.Id), default);
                Assert.True(get.IsSuccess); Assert.Equal(expected, get.Value.Status);
                var replay = await scope.ReplayAsync(fixture.Session, kind == "plan" ? save : request, fixture.Source, kind, default);
                Assert.NotNull(replay); Assert.True(replay.IsSuccess);
                Assert.Equal(expected, replay.Value.Status); Assert.Equal(original.Id, replay.Value.Id);
                Assert.Equal(7, replay.Value.Data.GetProperty("catalogRevision").GetInt64());
                Assert.Equal("suggested", original.Status);
                Assert.Equal(original.Payload, fixture.Session.Resources[kind].Payload);
            }
            var list = await queries.Handle(new ListMealPlansQuery(fixture.Source.BeneficiaryId), default);
            Assert.True(list.IsSuccess); Assert.Equal(expected, Assert.Single(list.Value).Status);
        }
    }

    [Theory]
    [InlineData("breakfast")]
    [InlineData("lunch")]
    [InlineData("dinner")]
    public async Task Replacement_query_excludes_incomplete_recipe_and_direct_replace_rejects_it(string mealType)
    {
        var fixture = new Fixture();
        var safe = CatalogFailClosedTests.Meal(mealType);
        var incomplete = safe with { VersionId = Guid.NewGuid(), AllergenDataComplete = false };
        fixture.Session.Recipes = [.. fixture.Session.Recipes, incomplete, safe];
        var query = new ReplacementOptionsQueryHandler(fixture, fixture, fixture, fixture);
        var options = await query.Handle(new ReplacementOptionsQuery(fixture.Source.BeneficiaryId,
            fixture.Recommendation.Id, mealType), default);
        Assert.True(options.IsSuccess);
        Assert.Equal(safe.VersionId, Assert.Single(options.Value).VersionId);
        var request = new ReplaceMealCommand(fixture.Source.BeneficiaryId, fixture.Recommendation.Id,
            new NutritionWriteInput(1, Guid.NewGuid(), RecipeVersionId: incomplete.VersionId, MealType: mealType));
        var result = await new ReplaceMealCommandHandler(new(fixture, fixture, fixture, fixture), new())
            .Handle(request, default);
        Assert.True(result.IsFailure);
        Assert.Equal("nutrition.content_changed", result.Error.Code);
        Assert.Equal(0, fixture.Session.Insertions);
    }

    private sealed class Fixture : IPeopleHealthClient, INutritionStore, ICurrentUser, INutritionFeatures
    {
        public BeneficiaryHealthSnapshot Source { get; } = EligibilityTests.Healthy() with
        { AllergyStatus = "reported_present", Allergies = JsonSerializer.SerializeToElement(new[] { "SHRIMP" }) };
        public Session Session { get; } = new();
        public NutritionResource Assessment => Session.Resources["assessment"];
        public NutritionResource Recommendation => Session.Resources["recommendation"];
        public Guid? UserId { get; } = Guid.NewGuid();
        public IReadOnlyList<string> Roles => ["CUSTOMER"];
        public bool Enabled => true;
        public bool AssessmentsEnabled => true;
        public bool RecommendationsEnabled => true;
        public Fixture()
        {
            Session.Recipes = [CatalogFailClosedTests.Meal("breakfast"), CatalogFailClosedTests.Meal("lunch"), CatalogFailClosedTests.Meal("dinner")];
            var assessment = Resource("confirmed", NutritionJson.Write(new AssessmentPayload(1, Source,
                CatalogFailClosedTests.Allergies, NutritionDecision.Create("eligible", []), CatalogRevision: 7)));
            Session.Resources["assessment"] = assessment;
            var payload = NutritionJson.Write(new MealPayload(1, assessment.Id, new(2026, 11, 9),
                Session.Recipes, [], NutritionDecision.Create("suggested", []), 7));
            Session.Resources["recommendation"] = Resource("suggested", payload);
            Session.Resources["plan"] = Resource("suggested", payload);
        }
        private NutritionResource Resource(string status, string payload) => new(Guid.NewGuid(), UserId!.Value,
            Source.BeneficiaryId, 1, status, payload, Guid.NewGuid(), "fixture", DateTimeOffset.UtcNow);
        public Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid owner, Guid beneficiary, CancellationToken ct) => Task.FromResult<BeneficiaryHealthSnapshot?>(Source);
        public Task<T> InOwnerScopeAsync<T>(Guid owner, Func<INutritionSession, Task<T>> action, CancellationToken ct) => action(Session);
        public Task<T> InRecommendationScopeAsync<T>(Guid owner, Guid key, Func<Task<T>> action, CancellationToken ct) => action();
        public Task<(Guid Owner, Guid Beneficiary, Guid Id, Guid Token, int Attempts)?> ClaimAsync(CancellationToken ct) => throw new NotSupportedException();
    }
    private sealed class Session : INutritionSession
    {
        public long Revision { get; set; } = 7;
        public Recipe[] Recipes { get; set; } = [];
        public Dictionary<string, NutritionResource> Resources { get; } = [];
        public int Insertions { get; private set; }
        public Task<NutritionResource?> GetAsync(string kind, Guid beneficiary, Guid id, CancellationToken ct) =>
            Task.FromResult(Resources.TryGetValue(kind, out var r) && r.Id == id ? r : null);
        public Task<NutritionResource?> FindByKeyAsync(string kind, Guid key, CancellationToken ct) =>
            Task.FromResult(Resources.TryGetValue(kind, out var r) && r.IdempotencyKey == key ? r : null);
        public Task InsertAsync(string kind, NutritionResource resource, CancellationToken ct) { Insertions++; return Task.CompletedTask; }
        public Task<bool> UpdateAsync(string kind, NutritionResource resource, Guid? leaseToken, CancellationToken ct) => throw new NotSupportedException();
        public Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<Recipe>>(Recipes);
        public Task<IReadOnlyList<DietaryRule>> RulesAsync(CancellationToken ct) => Task.FromResult<IReadOnlyList<DietaryRule>>([]);
        public Task<IReadOnlyList<NutritionResource>> PlansAsync(Guid beneficiary, CancellationToken ct, DateOnly? from = null, DateOnly? through = null) =>
            Task.FromResult<IReadOnlyList<NutritionResource>>([Resources["plan"]]);
        public Task<int> AssessmentCountAsync(CancellationToken ct) => Task.FromResult(0);
        public Task<IReadOnlyList<NutritionConcept>> ConceptsAsync(CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<NutritionConcept>>([new("SHRIMP", "food_allergy", ["SHRIMP"], 1)]);
        public Task<long> CatalogRevisionAsync(CancellationToken ct) => Task.FromResult(Revision);
    }
}
