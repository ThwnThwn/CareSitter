namespace CareSitter.Nutrition.Application;

public sealed record ReplaceMealCommand(Guid BeneficiaryId, Guid RecommendationId, NutritionWriteInput Input)
    : NutritionWriteCommand(BeneficiaryId, Input);
