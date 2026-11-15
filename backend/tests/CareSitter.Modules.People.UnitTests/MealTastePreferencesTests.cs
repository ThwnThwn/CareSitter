using System.Text.Json.Nodes;
using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.UnitTests;

public sealed class MealTastePreferencesTests
{
    [Fact]
    public void Approval_changes_only_soft_preferences_and_removes_same_meal_from_opposite_list()
    {
        const string history = """{"legacy":{"note":"keep"},"nutrition":{"schemaVersion":1,"swallowingStatus":"difficulty","preferredFoods":"Cá hấp; Bí đỏ","dislikedFoods":"Trứng"}}""";
        var result = MealTastePreferences.Apply(history, "Cá hấp", false);
        Assert.True(result.IsSuccess);
        var saved = JsonNode.Parse(result.Value)!;
        Assert.Equal("keep", saved["legacy"]!["note"]!.GetValue<string>());
        Assert.Equal("difficulty", saved["nutrition"]!["swallowingStatus"]!.GetValue<string>());
        Assert.Equal("Bí đỏ", saved["nutrition"]!["preferredFoods"]!.GetValue<string>());
        Assert.Equal("Trứng; Cá hấp", saved["nutrition"]!["dislikedFoods"]!.GetValue<string>());
        Assert.Equal(result.Value, MealTastePreferences.Apply(result.Value, "Cá hấp", false).Value);
    }

    [Fact]
    public void Full_preferences_and_unknown_schema_do_not_silently_drop_existing_preferences()
    {
        var history = new JsonObject { ["nutrition"] = new JsonObject { ["schemaVersion"] = 1,
            ["preferredFoods"] = string.Join(';', Enumerable.Range(1, 20).Select(i => "Món " + i)) } }.ToJsonString();
        Assert.Equal("nutrition.preferences_full", MealTastePreferences.Apply(history, "Cá hấp", true).Error.Code);
        Assert.True(MealTastePreferences.Apply("[]", "Cá hấp", true).IsFailure);
        Assert.True(MealTastePreferences.Apply("""{"nutrition":{"schemaVersion":2}}""", "Cá hấp", true).IsFailure);
    }
}
