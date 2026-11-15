namespace CareSitter.Nutrition.Application;

public interface INutritionStore
{
    Task<T> InRecommendationScopeAsync<T>(Guid owner, Guid key, Func<Task<T>> action, CancellationToken ct);
    Task<T> InOwnerScopeAsync<T>(Guid owner, Func<INutritionSession, Task<T>> action, CancellationToken ct);
    Task<(Guid Owner, Guid Beneficiary, Guid Id, Guid Token, int Attempts)?> ClaimAsync(CancellationToken ct);
}
