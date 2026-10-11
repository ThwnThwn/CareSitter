using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Primitives;
using MediatR;

namespace CareSitter.Nutrition.Application;

internal sealed class NutritionResourceQueryHandler(IPeopleHealthClient access, INutritionStore store,
    ICurrentUser user, INutritionFeatures features) : IRequestHandler<NutritionResourceQuery, Result<ResourceResponse>>,
    IRequestHandler<ListMealPlansQuery, Result<IReadOnlyList<ResourceResponse>>>
{
    public async Task<Result<ResourceResponse>> Handle(NutritionResourceQuery request, CancellationToken ct)
    {
        if (NutritionAccessRules.Check(user, features) is { } error) return error;
        var observation = await access.ReadAsync(user.UserId!.Value, request.BeneficiaryId, ct);
        if (observation is null) return NutritionAccessRules.Missing();
        var response = await store.InOwnerScopeAsync<Result<ResourceResponse>>(user.UserId.Value, async session =>
        {
            var value = await session.GetAsync(request.Kind, request.BeneficiaryId, request.ResourceId, ct);
            if (value is null) return NutritionAccessRules.Missing();
            var result = ResourceMapping.Map(value, observation.Revision);
            var catalogRevision = await session.CatalogRevisionAsync(ct);
            if (request.Kind == "assessment" && value.Status is not ("queued" or "processing") && NutritionJson.Read<AssessmentPayload>(value.Payload).CatalogRevision != catalogRevision)
                result = result with { Status = "stale" };
            if (request.Kind is "recommendation" or "plan" && result.Status != "stale")
            {
                var meal = NutritionJson.Read<MealPayload>(value.Payload);
                if (meal.CatalogRevision != catalogRevision || (meal.Meals.Length > 0 && !NutritionCommandHandler.ContentCurrent(meal, await session.RecipesAsync(ct), await session.RulesAsync(ct))))
                    result = result with { Status = "stale" };
            }
            return result;
        }, ct);
        var current = await access.ReadAsync(user.UserId.Value, request.BeneficiaryId, ct);
        if (current is null) return NutritionAccessRules.Missing();
        return response.IsSuccess && current.Revision != observation.Revision ? response.Value with { Status = "stale" } : response;
    }
    public async Task<Result<IReadOnlyList<ResourceResponse>>> Handle(ListMealPlansQuery request, CancellationToken ct)
    {
        if (NutritionAccessRules.Check(user, features) is { } error) return error;
        var observation = await access.ReadAsync(user.UserId!.Value, request.BeneficiaryId, ct);
        if (observation is null) return NutritionAccessRules.Missing();
        var response = await store.InOwnerScopeAsync<Result<IReadOnlyList<ResourceResponse>>>(user.UserId.Value, async session =>
        {
            var recipes = await session.RecipesAsync(ct); var rules = await session.RulesAsync(ct);
            var catalogRevision = await session.CatalogRevisionAsync(ct);
            return (await session.PlansAsync(request.BeneficiaryId, ct)).Select(r =>
            {
                var mapped = ResourceMapping.Map(r, observation.Revision);
                return NutritionJson.Read<MealPayload>(r.Payload).CatalogRevision == catalogRevision && ContentCurrent(r, recipes, rules) ? mapped : mapped with { Status = "stale" };
            }).ToArray();
        }, ct);
        var current = await access.ReadAsync(user.UserId.Value, request.BeneficiaryId, ct);
        if (current is null) return NutritionAccessRules.Missing();
        return response.IsSuccess && current.Revision != observation.Revision
            ? Result.Success<IReadOnlyList<ResourceResponse>>(response.Value.Select(r => r with { Status = "stale" }).ToArray())
            : response;
    }
    private static bool ContentCurrent(Domain.NutritionResource resource, IReadOnlyList<Domain.Recipe> recipes, IReadOnlyList<Domain.DietaryRule> rules) =>
        NutritionCommandHandler.ContentCurrent(NutritionJson.Read<MealPayload>(resource.Payload), recipes, rules);
}
