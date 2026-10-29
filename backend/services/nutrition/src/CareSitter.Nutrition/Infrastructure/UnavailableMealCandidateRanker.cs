using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class UnavailableMealCandidateRanker : IMealCandidateRanker
{
    public Task<MealCandidateRankingResult> RankAsync(MealCandidateRankingRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        return Task.FromResult(MealCandidateRankingResult.Unavailable("meal_ranking_not_configured"));
    }
}
