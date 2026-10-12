using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public interface INutritionSession
{
    Task<NutritionResource?> GetAsync(string kind, Guid beneficiary, Guid id, CancellationToken ct);
    Task<NutritionResource?> FindByKeyAsync(string kind, Guid key, CancellationToken ct);
    Task InsertAsync(string kind, NutritionResource resource, CancellationToken ct);
    Task<bool> UpdateAsync(string kind, NutritionResource resource, Guid? leaseToken, CancellationToken ct);
    Task<IReadOnlyList<Recipe>> RecipesAsync(CancellationToken ct);
    Task<IReadOnlyList<DietaryRule>> RulesAsync(CancellationToken ct);
    Task<IReadOnlyList<NutritionResource>> PlansAsync(Guid beneficiary, CancellationToken ct);
    Task<int> AssessmentCountAsync(CancellationToken ct);
    Task<IReadOnlyList<NutritionConcept>> ConceptsAsync(CancellationToken ct);
    Task<long> CatalogRevisionAsync(CancellationToken ct);
}
