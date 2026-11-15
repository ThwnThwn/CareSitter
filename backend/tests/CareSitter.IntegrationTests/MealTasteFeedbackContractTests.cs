using System.Text.Json;
using CareSitter.Modules.People.Controllers;

namespace CareSitter.IntegrationTests;

public sealed class MealTasteFeedbackContractTests
{
    [Fact]
    public void Review_must_explicitly_supply_approval_or_rejection()
    {
        var json = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<ReviewMealTasteFeedbackRequest>("{}", json));
        Assert.False(JsonSerializer.Deserialize<ReviewMealTasteFeedbackRequest>("{\"approve\":false}", json)!.Approve);
        Assert.True(JsonSerializer.Deserialize<ReviewMealTasteFeedbackRequest>("{\"approve\":true,\"expectedHealthRevision\":7}", json)!.Approve);
    }
}
