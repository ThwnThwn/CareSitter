namespace CareSitter.Nutrition.Application;

internal sealed class MealRecommendationEngine(IMealKnowledgeRetriever knowledge,
    IMealCandidateRanker ranker) : IMealRecommendationEngine
{
    public async Task<MealRecommendationResult> RecommendAsync(MealRecommendationRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var candidateSets = MealConstraintPolicy.CandidateSets(request.CandidateRecipes, request.Facts, request.Rules,
            request.DietaryPattern, request.NutritionGoal, recentMeals: request.RecentMeals);
        var meals = candidateSets.FirstOrDefault();
        if (meals is null)
            return new MealRecommendationResult(null,
                new(1, "rule_baseline", false, null, null, [], [], ["constraints_not_matched"]));

        var grounding = await knowledge.RetrieveAsync(new MealKnowledgeRequest(
            request.Facts.Where(fact => fact.Kind == "condition" && fact.Assertion == "present")
                .SelectMany(fact => new[] { fact.Code, fact.Label }).Distinct(StringComparer.Ordinal).ToArray(),
            request.Rules.SelectMany(rule => rule.DailyMaximums.Keys
                .Concat((rule.NutrientConstraints ?? []).Select(constraint => constraint.NutrientKey)))
                .Distinct(StringComparer.Ordinal).ToArray(),
            candidateSets.SelectMany(set => set).SelectMany(meal => meal.Ingredients.Select(ingredient => ingredient.Name))
                .Distinct(StringComparer.Ordinal).ToArray(),
            request.DietaryPattern, request.NutritionGoal), ct);
        var grounded = grounding.Available && grounding.Evidence.Length > 0;
        if (!grounded)
        {
            var warnings = grounding.Warnings.Length > 0 ? grounding.Warnings : ["grounding_not_applied"];
            return new MealRecommendationResult(meals, new(1, "rule_baseline", false, null, null,
                grounding.Evidence, [], warnings, grounding.Revision, grounding.Strategy));
        }

        var ranking = await ranker.RankAsync(new MealCandidateRankingRequest(request.CatalogRevision,
            candidateSets, request.Facts, request.Rules, grounding.Evidence,
            request.DietaryPattern, request.NutritionGoal, request.RecentMeals), ct);
        if (!ranking.Available)
            return new MealRecommendationResult(meals, new(1, "graph_grounded_rule", false, null, null,
                grounding.Evidence, [], grounding.Warnings.Concat(ranking.Warnings).Distinct().ToArray(),
                grounding.Revision, grounding.Strategy));

        var selected = candidateSets.FirstOrDefault(set =>
            set.Select(meal => meal.VersionId).SequenceEqual(ranking.SelectedRecipeVersionIds));
        if (selected is null || !MealConstraintPolicy.Matches(selected, request.Facts, request.Rules,
                request.DietaryPattern))
            return new MealRecommendationResult(meals, new(1, "graph_grounded_rule", false, null, null,
                grounding.Evidence, [], [.. grounding.Warnings, "meal_ranking_rejected"],
                grounding.Revision, grounding.Strategy));

        return new MealRecommendationResult(selected, new(1, "graph_grounded_ai_ranked", true,
            ranking.Model, ranking.PromptVersion, grounding.Evidence, ranking.Explanations,
            grounding.Warnings.Concat(ranking.Warnings).Distinct().ToArray(),
            grounding.Revision, grounding.Strategy));
    }
}
