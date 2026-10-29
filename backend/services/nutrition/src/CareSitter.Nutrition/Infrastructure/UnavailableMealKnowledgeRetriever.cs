using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class UnavailableMealKnowledgeRetriever : IMealKnowledgeRetriever
{
    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        return Task.FromResult(MealKnowledgeResult.Unavailable("grounding_not_configured"));
    }
}
