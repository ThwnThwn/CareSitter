using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class NutritionClarificationPolicy
{
    private const int MaximumQuestions = 3;

    public static NutritionDecision Attach(NutritionDecision decision,
        IReadOnlyList<HealthUnresolvedStatement>? unresolved = null)
    {
        if (decision.State != "needs_information") return decision with { Questions = [] };
        var candidates = new List<Candidate>();
        foreach (var item in unresolved ?? [])
        {
            var source = $"textSources/{item.SourceKey}";
            candidates.Add(item.Reason switch
            {
                "ambiguous_subject" => new(0, new("clarify-subject.v1", source, "single_choice",
                    ["beneficiary", "other", "unknown"], true, "confirm_subject")),
                "ambiguous_assertion" => new(5, new("clarify-assertion.v1", source, "single_choice",
                    ["present", "absent", "unknown"], true, "confirm_assertion")),
                "ambiguous_temporality" => new(6, new("clarify-temporality.v1", source, "single_choice",
                    ["current", "past", "unknown"], true, "confirm_temporality")),
                "unknown_concept" => new(45, new("review-unknown-concept.v1", source, "review_source",
                    [], true, "identify_health_information")),
                "insufficient_detail" => new(46, new("add-health-detail.v1", source, "review_source",
                    [], true, "add_required_detail")),
                _ => new(50, new("review-health-note.v1", source, "review_source",
                    [], true, "review_unresolved_information"))
            });
        }

        foreach (var conflict in decision.Conflicts ?? []) candidates.Add(Conflict(conflict));
        foreach (var field in decision.MissingFields ?? []) candidates.Add(Missing(field));

        var questions = candidates.OrderBy(candidate => candidate.Priority)
            .ThenBy(candidate => candidate.Question.Id, StringComparer.Ordinal)
            .ThenBy(candidate => candidate.Question.SourceField, StringComparer.Ordinal)
            .Select(candidate => candidate.Question)
            .DistinctBy(question => (question.Id, question.SourceField))
            .Take(MaximumQuestions).ToArray();
        return decision with { Questions = questions };
    }

    private static Candidate Conflict(string code) => code switch
    {
        "allergy_sources_conflict" => new(10, new("resolve-food-allergy-conflict.v1", "allergies",
            "review_profile", [], true, "resolve_food_allergy_conflict")),
        "condition_sources_conflict" => new(20, new("resolve-condition-conflict.v1", "chronicConditions",
            "review_profile", [], true, "resolve_condition_conflict")),
        "medication_sources_conflict" => new(30, new("resolve-medication-conflict.v1", "medications",
            "review_profile", [], true, "resolve_medication_conflict")),
        _ => new(40, new("resolve-health-source-conflict.v1", "healthProfile",
            "review_profile", [], true, "resolve_source_conflict"))
    };

    private static Candidate Missing(string field) => field switch
    {
        "foodAllergyStatus" => new(11, new("food-allergy-status.v1", field, "single_choice",
            ["reported_none", "reported_present", "unknown"], true, "confirm_food_allergy_status")),
        "allergies" => new(12, new("food-allergy-list.v1", field, "list",
            [], true, "list_food_allergies")),
        "conditionsStatus" => new(21, new("condition-status.v1", field, "single_choice",
            ["reported_none", "reported_present", "unknown"], true, "confirm_condition_status")),
        "chronicConditions" => new(22, new("condition-list.v1", field, "list",
            [], true, "list_reported_conditions")),
        "healthHistory/nutrition/medicationsStatus" => new(31, new("medication-status.v1", field,
            "single_choice", ["reported_none", "reported_present", "unknown"], true,
            "confirm_medication_status")),
        "medications" => new(32, new("medication-list.v1", field, "list",
            [], true, "list_current_medications")),
        "dateOfBirth" => new(35, new("date-of-birth.v1", field, "date",
            [], true, "confirm_date_of_birth")),
        "healthHistory/nutrition/feedingRoute" => Choice(36, "feeding-route.v1", field,
            ["oral", "tube", "unknown"], "confirm_feeding_route"),
        "healthHistory/nutrition/swallowingStatus" => Choice(37, "swallowing-status.v1", field,
            ["normal", "difficulty", "unknown"], "confirm_swallowing_status"),
        "healthHistory/nutrition/fluidRestriction" => Choice(38, "fluid-restriction.v1", field,
            ["none", "present", "unknown"], "confirm_fluid_restriction"),
        "healthHistory/nutrition/electrolyteRestriction" => Choice(39, "electrolyte-restriction.v1", field,
            ["none", "present", "unknown"], "confirm_electrolyte_restriction"),
        "unresolvedHealthFacts" => new(44, new("review-uncertain-health-facts.v1", field,
            "review_profile", [], true, "review_uncertain_health_information")),
        _ when field.StartsWith("textSources/", StringComparison.Ordinal) => new(50,
            new("review-health-note.v1", SourceWithoutOffset(field), "review_source", [], true,
                "review_unresolved_information")),
        _ => new(60, new("complete-health-profile.v1", field, "review_profile",
            [], true, "complete_required_health_information"))
    };

    private static Candidate Choice(int priority, string id, string source, string[] options, string purpose) =>
        new(priority, new(id, source, "single_choice", options, true, purpose));

    private static string SourceWithoutOffset(string field)
    {
        var parts = field.Split('/', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 2 ? $"textSources/{parts[1]}" : "healthProfile";
    }

    private sealed record Candidate(int Priority, NutritionQuestion Question);
}
