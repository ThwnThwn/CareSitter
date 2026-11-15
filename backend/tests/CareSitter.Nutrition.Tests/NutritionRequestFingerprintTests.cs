using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Tests;

public sealed class NutritionRequestFingerprintTests
{
    [Theory]
    [InlineData("assess")]
    [InlineData("recommend")]
    [InlineData("replace")]
    [InlineData("save")]
    [InlineData("assess-with-resource")]
    public void Typed_commands_preserve_previously_persisted_retry_identity(string operation)
    {
        var beneficiary = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var key = Guid.Parse("22222222-2222-2222-2222-222222222222");
        var resource = Guid.Parse("33333333-3333-3333-3333-333333333333");
        var carriesResource = operation == "assess-with-resource";
        if (carriesResource) operation = "assess";
        var input = new NutritionWriteInput(7, key, PlannedDate: new(2027, 1, 1), MealType: "lunch")
        { FingerprintResourceId = carriesResource ? resource : null };
        NutritionWriteCommand command = operation switch
        {
            "assess" => new AssessNutritionCommand(beneficiary, input),
            "recommend" => new RecommendMealsCommand(beneficiary, input),
            "replace" => new ReplaceMealCommand(beneficiary, resource, input),
            _ => new SaveMealPlanCommand(beneficiary, resource, input)
        };
        var resourceJson = carriesResource || operation is "replace" or "save" ? "\"33333333-3333-3333-3333-333333333333\"" : "null";
        // Wire fixture from the original NutritionCommand serializer; include unused fields and nulls.
        var persistedJson = "{\"operation\":\"" + operation + "\",\"beneficiaryId\":\"11111111-1111-1111-1111-111111111111\",\"expectedHealthRevision\":7,\"idempotencyKey\":\"22222222-2222-2222-2222-222222222222\",\"resourceId\":" + resourceJson + ",\"assessmentId\":null,\"plannedDate\":\"2027-01-01\",\"recipeVersionId\":null,\"mealType\":\"lunch\"}";
        var expected = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(persistedJson)));
        Assert.Equal(expected, NutritionRequestFingerprint.For(command));
        Assert.NotEqual(expected, NutritionRequestFingerprint.For(command with { Input = input with { PlannedDate = new(2027, 1, 2) } }));
    }
}
