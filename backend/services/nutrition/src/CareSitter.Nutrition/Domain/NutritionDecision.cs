namespace CareSitter.Nutrition.Domain;

public sealed record NutritionDecision(string State, string[] ReasonCodes, string[] MissingFields,
    string[] Conflicts, string[] RequiredGuidance, string[] AllowedActions)
{
    public NutritionQuestion[] Questions { get; init; } = [];

    public static NutritionDecision Failure(string code, bool retryable) => new("failed", [code], [], [], [],
        retryable ? ["retry"] : ["edit_health"]);

    public static NutritionDecision Create(string state, string[] reasons, string[]? missing = null,
        string[]? conflicts = null, string[]? guidance = null) => new(state, reasons,
            missing ?? [], conflicts ?? [], guidance ?? [], state switch
            {
                "needs_information" or "needs_professional_guidance" => ["edit_health"],
                "awaiting_confirmation" => ["edit_health", "confirm"],
                "eligible" => ["recommend"],
                "suggested" => ["replace", "save"],
                "failed" => ["retry"],
                "stale" => ["reload"],
                _ => ["edit_health"]
            });
}
