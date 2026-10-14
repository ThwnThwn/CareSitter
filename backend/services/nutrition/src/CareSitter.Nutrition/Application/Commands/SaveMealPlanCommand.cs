namespace CareSitter.Nutrition.Application;

public sealed record SaveMealPlanCommand(Guid BeneficiaryId, Guid RecommendationId, NutritionWriteInput Input)
    : NutritionWriteCommand(BeneficiaryId, Input);
