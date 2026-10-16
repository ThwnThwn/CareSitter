using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;
using CareSitter.Nutrition.Application.Catalog;

namespace CareSitter.Nutrition.Application;

public static class NutritionEligibilityPolicy
{
    public static NutritionDecision Evaluate(BeneficiaryHealthSnapshot snapshot, NormalizedHealth health,
        IReadOnlyList<HealthFact> facts, IReadOnlyList<DietaryRule> rules, bool confirmed)
    {
        var beneficiaryFacts = facts.Where(f => f.Subject == "beneficiary").ToArray();
        var relevant = beneficiaryFacts.Where(f => f.Assertion != "absent" && f.Temporality != "past").ToArray();
        var conflicts = new List<string>();
        if (snapshot.AllergyStatus == "reported_none" && relevant.Any(f => f.Kind == "food_allergy")) conflicts.Add("allergy_sources_conflict");
        if (health.Evidence.GetValueOrDefault("conditionsStatus") == "reported_none" && relevant.Any(f => f.Kind == "condition")) conflicts.Add("condition_sources_conflict");
        if (health.Evidence.GetValueOrDefault("medicationsStatus") == "reported_none" && health.Evidence.ContainsKey("activeMedications")) conflicts.Add("medication_sources_conflict");
        if (beneficiaryFacts.GroupBy(f => (f.Kind, f.Code)).Any(g => g.Select(f => f.Assertion).Distinct().Count() > 1)) conflicts.Add("source_conflict");
        if (conflicts.Count > 0) return NutritionClarificationPolicy.Attach(
            NutritionDecision.Create("needs_information", ["source_conflict"], conflicts: conflicts.ToArray()));
        var clinicianOnly = relevant.Where(f => f.Kind == "condition" && f.Assertion == "present" &&
                f.Temporality == "current" && CatalogPolicyVocabulary.ClinicianOnlyConditions.Contains(f.Code))
            .Select(f => f.Code).Distinct(StringComparer.Ordinal).ToArray();
        if (clinicianOnly.Length > 0)
            return NutritionDecision.Create("needs_professional_guidance", ["special_guidance_required"], guidance: clinicianOnly);
        if (health.SpecialNeeds.Length > 0 || relevant.Any(f => f.Code is "DYSPHAGIA" or "TUBE_FEEDING" or "FLUID_RESTRICTION" or "ELECTROLYTE_RESTRICTION"))
            return NutritionDecision.Create("needs_professional_guidance", ["special_guidance_required"], guidance: health.SpecialNeeds.Length > 0 ? health.SpecialNeeds : ["specialized_diet"]);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (snapshot.DateOfBirth is { } birthDate && birthDate <= today && AgeOn(birthDate, today) < 18)
            return NutritionDecision.Create("needs_professional_guidance", ["unsupported_population"], guidance: ["under_18"]);
        var conditions = relevant.Where(f => f.Kind == "condition" && f.Assertion == "present" && f.Temporality == "current").ToArray();
        var unsupported = conditions.Where(c => !rules.Any(r => r.ConditionCode == c.Code && ValidRule(r)))
            .Select(c => c.Code).Distinct(StringComparer.Ordinal).ToArray();
        if (unsupported.Length > 0)
            return NutritionDecision.Create("needs_professional_guidance", ["unsupported_condition"], guidance: unsupported);
        var missing = new List<string>();
        if (snapshot.DateOfBirth is null || snapshot.DateOfBirth > today || AgeOn(snapshot.DateOfBirth.Value, today) > 120) missing.Add("dateOfBirth");
        if (snapshot.AllergyStatus is not ("reported_none" or "reported_present") || snapshot.AllergyConfirmedAt is null) missing.Add("foodAllergyStatus");
        if (!health.ConditionsDeclared) missing.Add("conditionsStatus");
        foreach (var field in new[] { "medicationsStatus", "feedingRoute", "swallowingStatus", "fluidRestriction", "electrolyteRestriction" })
            if (!health.Evidence.TryGetValue(field, out var value) || value == "unknown") missing.Add("healthHistory/nutrition/" + field);
        if (health.Evidence.GetValueOrDefault("medicationsStatus") == "reported_present" && !health.Evidence.ContainsKey("activeMedications")) missing.Add("medications");
        if (health.Evidence.GetValueOrDefault("conditionsStatus") == "reported_present" && conditions.Length == 0) missing.Add("chronicConditions");
        if (snapshot.AllergyStatus == "reported_present" && !relevant.Any(f => f.Kind == "food_allergy")) missing.Add("allergies");
        missing.AddRange(health.Unresolved);
        if (relevant.Any(f => f.Kind == "symptom" || f.Assertion == "uncertain" || f.Temporality == "unknown")) missing.Add("unresolvedHealthFacts");
        var applicable = rules.Where(r => conditions.Any(c => c.Code == r.ConditionCode) && ValidRule(r)).ToArray();
        foreach (var rule in applicable)
            missing.AddRange(rule.Prerequisites.Where(p => !Matches(p, health.Evidence)).Select(p => "healthHistory/nutrition/" + p.Field));
        if (missing.Count > 0) return NutritionClarificationPolicy.Attach(
            NutritionDecision.Create("needs_information", ["missing_information"], missing.Distinct().ToArray()));
        // No approved medication/food interaction catalog exists yet. Preserve the regimen and route it for review.
        if (health.Evidence.ContainsKey("activeMedications"))
            return NutritionDecision.Create("needs_professional_guidance", ["medication_review_required"], guidance: ["medications"]);
        return NutritionDecision.Create(confirmed ? "eligible" : "awaiting_confirmation", []);
    }

    public static bool ValidRule(DietaryRule r) => !string.IsNullOrWhiteSpace(r.ConditionCode) &&
        r.Prerequisites is not null && r.ExcludedIngredients is not null && r.DailyMaximums is not null &&
        r.Prerequisites.All(CatalogBundleValidator.IsSupported) && r.ExcludedIngredients.All(i => !string.IsNullOrWhiteSpace(i)) &&
        r.Sources is { Length: > 0 } && r.Sources.All(s => !string.IsNullOrWhiteSpace(s)) && r.DailyMaximums.All(p => p.Value >= 0) &&
        (r.NutrientConstraints is null ||
         r.NutrientConstraints.All(c => c is not null && IsValidConstraint(c)) &&
         r.NutrientConstraints.Select(c => (c.NutrientKey, c.Scope, c.MealType)).Distinct().Count() == r.NutrientConstraints.Length);

    private static bool IsValidConstraint(NutrientConstraint constraint) =>
        !string.IsNullOrWhiteSpace(constraint.NutrientKey) &&
        CatalogPolicyVocabulary.NutrientConstraintScopes.Contains(constraint.Scope) &&
        (constraint.Scope == "daily" ? constraint.MealType is null : CatalogPolicyVocabulary.MealTypes.Contains(constraint.MealType ?? string.Empty)) &&
        (constraint.Minimum is not null || constraint.Maximum is not null) &&
        constraint.Minimum is null or >= 0 && constraint.Maximum is null or >= 0 &&
        (constraint.Minimum is null || constraint.Maximum is null || constraint.Minimum <= constraint.Maximum);

    private static bool Matches(RulePrerequisite prerequisite, IReadOnlyDictionary<string, string> evidence)
    {
        if (!CatalogBundleValidator.IsSupported(prerequisite) || !evidence.TryGetValue(prerequisite.Field, out var actual) ||
            string.IsNullOrWhiteSpace(actual) || actual == "unknown") return false;
        return prerequisite.Operator switch
        {
            "known" => true,
            "equals" => prerequisite.Values.Length == 1 && actual == prerequisite.Values[0],
            "one_of" => prerequisite.Values.Contains(actual, StringComparer.Ordinal),
            _ => false
        };
    }

    private static int AgeOn(DateOnly birthDate, DateOnly date)
    {
        var age = date.Year - birthDate.Year;
        return birthDate > date.AddYears(-age) ? age - 1 : age;
    }
}
