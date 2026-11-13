using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class ReleasedGraphMealKnowledgeRetriever(
    IOptions<MealGroundingOptions> options, IHostEnvironment environment) : IMealKnowledgeRetriever
{
    private readonly ReleasedRetrievalMealKnowledgeRetriever _released = new(options, environment);
    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct) =>
        _released.RetrieveAsync(request, ct);
}
