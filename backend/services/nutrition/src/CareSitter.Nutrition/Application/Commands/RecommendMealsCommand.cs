namespace CareSitter.Nutrition.Application;

public sealed record RecommendMealsCommand(Guid BeneficiaryId, NutritionWriteInput Input)
    : NutritionWriteCommand(BeneficiaryId, Input);
