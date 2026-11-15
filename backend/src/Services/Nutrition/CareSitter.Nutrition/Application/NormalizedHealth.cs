using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public sealed record NormalizedHealth(HealthFact[] Facts, string[] Unresolved,
    Dictionary<string, string> TextSources, Dictionary<string, string> Evidence,
    string[] SpecialNeeds, bool ConditionsDeclared);
