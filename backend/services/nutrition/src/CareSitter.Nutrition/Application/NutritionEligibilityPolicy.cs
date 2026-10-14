using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class NutritionEligibilityPolicy
{
    public static NutritionDecision Evaluate(BeneficiaryHealthSnapshot snapshot, NormalizedHealth health,
        IReadOnlyList<HealthFact> facts, IReadOnlyList<DietaryRule> rules, bool confirmed)
    {
        var relevant = facts.Where(f => f.Assertion != "absent" && f.Temporality != "past").ToArray();
        var conflicts = new List<string>();
        if (snapshot.AllergyStatus == "reported_none" && relevant.Any(f => f.Kind == "food_allergy")) conflicts.Add("allergy_sources_conflict");
        if (health.Evidence.GetValueOrDefault("conditionsStatus") == "reported_none" && relevant.Any(f => f.Kind == "condition")) conflicts.Add("condition_sources_conflict");
        if (health.Evidence.GetValueOrDefault("medicationsStatus") == "reported_none" && health.Evidence.ContainsKey("activeMedications")) conflicts.Add("medication_sources_conflict");
        if (facts.GroupBy(f => (f.Kind, f.Code)).Any(g => g.Select(f => f.Assertion).Distinct().Count() > 1)) conflicts.Add("source_conflict");
        if (conflicts.Count > 0) return NutritionDecision.Create("needs_information", ["source_conflict"], conflicts: conflicts.ToArray());
        if (health.SpecialNeeds.Length > 0 || relevant.Any(f => f.Code is "KIDNEY_DISEASE" or "DYSPHAGIA" or "TUBE_FEEDING" or "FLUID_RESTRICTION" or "ELECTROLYTE_RESTRICTION"))
            return NutritionDecision.Create("needs_professional_guidance", ["special_guidance_required"], guidance: health.SpecialNeeds.Length > 0 ? health.SpecialNeeds : ["specialized_diet"]);
        var conditions = relevant.Where(f => f.Kind == "condition" && f.Assertion == "present" && f.Temporality == "current").ToArray();
        if (conditions.Any(c => !rules.Any(r => r.ConditionCode == c.Code && ValidRule(r))))
            return NutritionDecision.Create("needs_professional_guidance", ["unsupported_condition"], guidance: conditions.Select(c => c.Code).Distinct().ToArray());
        var missing = new List<string>();
        if (snapshot.AllergyStatus is not ("reported_none" or "reported_present") || snapshot.AllergyConfirmedAt is null) missing.Add("foodAllergyStatus");
        if (!health.ConditionsDeclared) missing.Add("conditionsStatus");
        foreach (var field in new[] { "medicationsStatus", "feedingRoute", "swallowingStatus", "fluidRestriction", "electrolyteRestriction" })
            if (!health.Evidence.TryGetValue(field, out var value) || value == "unknown") missing.Add("healthHistory/nutrition/" + field);
        if (health.Evidence.GetValueOrDefault("medicationsStatus") == "reported_present" && !health.Evidence.ContainsKey("activeMedications")) missing.Add("medications");
        if (health.Evidence.GetValueOrDefault("conditionsStatus") == "reported_present" && conditions.Length == 0) missing.Add("chronicConditions");
        if (snapshot.AllergyStatus == "reported_present" && !relevant.Any(f => f.Kind == "food_allergy")) missing.Add("allergies");
        missing.AddRange(health.Unresolved);
        if (relevant.Any(f => f.Kind == "symptom" || f.Assertion == "uncertain" || f.Temporality == "unknown" || f.Subject != "beneficiary")) missing.Add("unresolvedHealthFacts");
        var applicable = rules.Where(r => conditions.Any(c => c.Code == r.ConditionCode) && ValidRule(r)).ToArray();
        foreach (var rule in applicable)
            missing.AddRange(rule.Prerequisites.Where(p => !health.Evidence.TryGetValue(p, out var v) || string.IsNullOrWhiteSpace(v)));
        if (missing.Count > 0) return NutritionDecision.Create("needs_information", ["missing_information"], missing.Distinct().ToArray());
        // No approved medication/food interaction catalog exists yet. Preserve the regimen and route it for review.
        if (health.Evidence.ContainsKey("activeMedications"))
            return NutritionDecision.Create("needs_professional_guidance", ["medication_review_required"], guidance: ["medications"]);
        return NutritionDecision.Create(confirmed ? "eligible" : "awaiting_confirmation", []);
    }

    public static bool ValidRule(DietaryRule r) => !string.IsNullOrWhiteSpace(r.ConditionCode) &&
        r.Prerequisites is not null && r.ExcludedIngredients is not null && r.DailyMaximums is not null &&
        r.Prerequisites.All(p => !string.IsNullOrWhiteSpace(p)) && r.ExcludedIngredients.All(i => !string.IsNullOrWhiteSpace(i)) &&
        r.Sources is { Length: > 0 } && r.Sources.All(s => !string.IsNullOrWhiteSpace(s)) && r.DailyMaximums.All(p => p.Value >= 0);
}
