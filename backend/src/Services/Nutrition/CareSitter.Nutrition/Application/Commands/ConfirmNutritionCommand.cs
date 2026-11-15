namespace CareSitter.Nutrition.Application;

public sealed record ConfirmNutritionCommand(Guid BeneficiaryId, Guid AssessmentId, NutritionWriteInput Input)
    : NutritionWriteCommand(BeneficiaryId, Input);
