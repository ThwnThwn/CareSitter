using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Nutrition.Application;

internal static class NutritionRequestFingerprint
{
    public static string For(NutritionWriteCommand command)
    {
        var (operation, resourceId) = command switch
        {
            AssessNutritionCommand => ("assess", command.Input.FingerprintResourceId),
            ConfirmNutritionCommand confirm => ("confirm", (Guid?)confirm.AssessmentId),
            RecommendMealsCommand => ("recommend", command.Input.FingerprintResourceId),
            ReplaceMealCommand replace => ("replace", (Guid?)replace.RecommendationId),
            SaveMealPlanCommand save => ("save", (Guid?)save.RecommendationId),
            _ => throw new ArgumentException("Unknown nutrition command.", nameof(command))
        };
        var input = command.Input;
        // Preserve the original property order and nulls: previously stored keys
        // must still recognize retries after the command refactor is deployed.
        var identity = new PersistedRequestIdentity(operation, command.BeneficiaryId,
            input.ExpectedHealthRevision, input.IdempotencyKey, resourceId, input.AssessmentId,
            input.PlannedDate, input.RecipeVersionId, input.MealType);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(NutritionJson.Write(identity))));
    }

    private sealed record PersistedRequestIdentity(string Operation, Guid BeneficiaryId, long ExpectedHealthRevision,
        Guid IdempotencyKey, Guid? ResourceId, Guid? AssessmentId, DateOnly? PlannedDate,
        Guid? RecipeVersionId, string? MealType);
}
