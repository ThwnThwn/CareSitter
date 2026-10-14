namespace CareSitter.Nutrition.Application;

public sealed record AssessNutritionCommand(Guid BeneficiaryId, NutritionWriteInput Input)
    : NutritionWriteCommand(BeneficiaryId, Input);
