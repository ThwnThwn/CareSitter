using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

internal sealed class MealRecommendationEngine(IMealKnowledgeRetriever knowledge,
    IMealCandidateRanker ranker) : IMealRecommendationEngine
{
    public async Task<MealRecommendationResult> RecommendAsync(MealRecommendationRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var candidateSets = MealConstraintPolicy.CandidateSets(request.CandidateRecipes, request.Facts, request.Rules,
            request.DietaryPattern, request.NutritionGoal, recentMeals: request.RecentMeals,
            previousMenus: request.PreviousMenus, preferences: request.Preferences);
        var meals = candidateSets.FirstOrDefault();
        if (meals is null)
            return new MealRecommendationResult(null,
                new(2, "rule_baseline", false, null, null, [], [], ["constraints_not_matched"], ReleaseStatus: "ungrounded"));

        var grounding = await knowledge.RetrieveAsync(new MealKnowledgeRequest(
            request.Facts.Where(fact => fact.Kind == "condition" && fact.Assertion == "present")
                .SelectMany(fact => new[] { fact.Code, fact.Label }).Distinct(StringComparer.Ordinal).ToArray(),
            request.Rules.SelectMany(rule => rule.DailyMaximums.Keys
                .Concat((rule.NutrientConstraints ?? []).Select(constraint => constraint.NutrientKey)))
                .Distinct(StringComparer.Ordinal).ToArray(),
            candidateSets.SelectMany(set => set).SelectMany(meal => meal.Ingredients.Select(ingredient => ingredient.Name))
                .Distinct(StringComparer.Ordinal).ToArray(),
            request.DietaryPattern, request.NutritionGoal), ct);
        var releaseStatus = grounding.ReleaseStatus;
        // Catalog reader admits only integrity-checked published payloads or explicit local demo.
        // A reference catalog must never promote an unauthorized/demo retriever to reference.
        if (meals.Any(recipe => recipe.Name.StartsWith("[DEMO]", StringComparison.Ordinal)))
            releaseStatus = "demo";
        else if (releaseStatus == "released" && meals.Any(recipe => recipe.ReviewPolicy == "non_medical_reference"))
            releaseStatus = "reference";
        var grounded = grounding.Available && grounding.Evidence.Length > 0;
        if (!grounded)
        {
            var warnings = grounding.Warnings.Length > 0 ? grounding.Warnings : ["grounding_not_applied"];
            return new MealRecommendationResult(meals, new(1, "rule_baseline", false, null, null,
                grounding.Evidence, [], warnings, grounding.Revision, grounding.Strategy, "ungrounded")
                { VerifiedReasons = VerifiedReasons(meals, request) });
        }

        MealRecommendationTrace Trace(string strategy, bool usedAi, string? model, string? prompt,
            MealRecommendationExplanation[] explanations, string[] warnings, Recipe[] chosen) =>
            new(2, strategy, usedAi, model, prompt, grounding.Evidence, explanations, warnings,
                grounding.Revision, grounding.Strategy, releaseStatus)
            {
                // Retrieval facts are claimed only for a validated release, never for demo content.
                RetrievalStrategy = releaseStatus is "reference" or "released" ? grounding.Strategy : null,
                GraphRole = releaseStatus is "reference" or "released" ? grounding.GraphRole : "none",
                Citations = grounding.Evidence.Select(e => new MealCitation(e.SourceTitle ?? e.Reference,
                    e.Chapter, e.Title, e.PrintedPages, e.GraphPath)).ToArray(),
                VerifiedReasons = VerifiedReasons(chosen, request),
                Disclaimer = releaseStatus == "released" ? NutritionDisclaimer.Reviewed : NutritionDisclaimer.Reference,
                DisclaimerVersion = releaseStatus == "released" ? NutritionDisclaimer.ReviewedVersion : NutritionDisclaimer.ReferenceVersion
            };

        var ranking = await ranker.RankAsync(new MealCandidateRankingRequest(request.CatalogRevision,
            candidateSets, request.Facts, request.Rules, grounding.Evidence,
            request.DietaryPattern, request.NutritionGoal, request.RecentMeals,
            request.Preferences), ct);
        if (!ranking.Available)
            return new MealRecommendationResult(meals, Trace("graph_grounded_rule", false, null, null,
                [], grounding.Warnings.Concat(ranking.Warnings).Distinct().ToArray(), meals));

        var selected = candidateSets.FirstOrDefault(set =>
            set.Select(meal => meal.VersionId).SequenceEqual(ranking.SelectedRecipeVersionIds));
        if (selected is null || !MealConstraintPolicy.Matches(selected, request.Facts, request.Rules,
                request.DietaryPattern))
            return new MealRecommendationResult(meals, Trace("graph_grounded_rule", false, null, null,
                [], [.. grounding.Warnings, "meal_ranking_rejected"], meals));

        return new MealRecommendationResult(selected, Trace("graph_grounded_ai_ranked", true,
            ranking.Model, ranking.PromptVersion, ranking.Explanations,
            grounding.Warnings.Concat(ranking.Warnings).Distinct().ToArray(), selected));
    }

    private static MealVerifiedReason[] VerifiedReasons(Recipe[] meals, MealRecommendationRequest request)
        => MealReasonBuilder.Build(meals, request);
}
