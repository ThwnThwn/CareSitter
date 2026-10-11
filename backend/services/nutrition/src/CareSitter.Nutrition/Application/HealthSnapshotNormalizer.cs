using System.Text.Json;
using CareSitter.Nutrition.Contracts;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class HealthSnapshotNormalizer
{
    public static NormalizedHealth Normalize(BeneficiaryHealthSnapshot source, IReadOnlyList<NutritionConcept> concepts)
    {
        var facts = new List<HealthFact>(); var unresolved = new List<string>();
        var text = new Dictionary<string, string>(); var evidence = new Dictionary<string, string>(); var special = new List<string>();
        void Text(string key, string? value) { if (!string.IsNullOrWhiteSpace(value)) text[key] = value; }
        Text("generalNote", source.GeneralNote); Text("careInstructions", source.CareInstructions); Text("mobilityNote", source.MobilityNote);
        void ReadArray(string key, JsonElement? raw, string kind)
        {
            if (raw is null || raw.Value.ValueKind == JsonValueKind.Null) return;
            var value = raw.Value;
            if (value.ValueKind != JsonValueKind.Array || value.GetArrayLength() > 40) { unresolved.Add(key); return; }
            var index = 0;
            foreach (var item in value.EnumerateArray())
            {
                var pointer = $"{key}/{index++}";
                string? label = null, code = null; var assertion = "present"; var temporality = "current";
                if (item.ValueKind == JsonValueKind.String) label = item.GetString();
                else if (item.ValueKind == JsonValueKind.Object)
                {
                    if (item.TryGetProperty("label", out var l) && l.ValueKind == JsonValueKind.String) label = l.GetString();
                    if (item.TryGetProperty("code", out var c) && c.ValueKind == JsonValueKind.String) code = c.GetString();
                    if (item.TryGetProperty("assertion", out var a) && a.ValueKind == JsonValueKind.String) assertion = a.GetString()!;
                    if (item.TryGetProperty("temporality", out var t) && t.ValueKind == JsonValueKind.String) temporality = t.GetString()!;
                }
                var concept = concepts.FirstOrDefault(x => x.Kind == kind &&
                    ((code is not null && x.Code == code) || x.Aliases.Any(a => string.Equals(a, label, StringComparison.OrdinalIgnoreCase))));
                if (concept is null || assertion is not ("present" or "absent" or "uncertain") || temporality is not ("current" or "past" or "unknown"))
                { unresolved.Add(pointer); continue; }
                facts.Add(new(kind, concept.Code, label ?? concept.Code, assertion, temporality, pointer, item.GetRawText(), "beneficiary"));
            }
        }
        ReadArray("allergies", source.Allergies, "food_allergy");
        ReadArray("chronicConditions", source.ChronicConditions, "condition");
        var declared = false;
        if (source.HealthHistory is { ValueKind: JsonValueKind.Object } history && history.TryGetProperty("nutrition", out var nutrition) && nutrition.ValueKind == JsonValueKind.Object)
        {
            if (!nutrition.TryGetProperty("schemaVersion", out var version) || version.GetRawText() != "1")
                unresolved.Add("healthHistory/nutrition/schemaVersion");
            var known = new HashSet<string> { "schemaVersion", "conditionsStatus", "feedingRoute", "swallowingStatus", "fluidRestriction", "electrolyteRestriction", "guidance", "symptoms" };
            foreach (var prop in nutrition.EnumerateObject())
            {
                if (!known.Contains(prop.Name)) { unresolved.Add("healthHistory/nutrition/" + prop.Name); continue; }
                if (prop.Name == "schemaVersion") { if (prop.Value.GetRawText() != "1") unresolved.Add("healthHistory/nutrition/schemaVersion"); continue; }
                if (prop.Value.ValueKind != JsonValueKind.String) { unresolved.Add("healthHistory/nutrition/" + prop.Name); continue; }
                var v = prop.Value.GetString()!; evidence[prop.Name] = v;
                var valid = prop.Name switch
                {
                    "conditionsStatus" => v is "reported_none" or "reported_present",
                    "feedingRoute" => v is "oral" or "tube",
                    "swallowingStatus" => v is "normal" or "difficulty",
                    "fluidRestriction" or "electrolyteRestriction" => v is "none" or "present",
                    _ => true
                };
                if (!valid) unresolved.Add("healthHistory/nutrition/" + prop.Name);
                if (prop.Name == "conditionsStatus") declared = v == "reported_none" || v == "reported_present";
                if ((prop.Name == "feedingRoute" && v == "tube") || (prop.Name == "swallowingStatus" && v == "difficulty") ||
                    (prop.Name is "fluidRestriction" or "electrolyteRestriction" && v == "present")) special.Add(prop.Name);
                if (prop.Name is "symptoms" or "guidance") Text("healthHistory/nutrition/" + prop.Name, v);
            }
            if (history.EnumerateObject().Any(p => p.Name != "nutrition")) unresolved.Add("healthHistory/legacy");
        }
        else if (source.HealthHistory is { ValueKind: not JsonValueKind.Null }) unresolved.Add("healthHistory");
        if (source.Medications is { ValueKind: not JsonValueKind.Null } medications &&
            (medications.ValueKind != JsonValueKind.Array || medications.GetArrayLength() > 0)) unresolved.Add("medications");
        return new(facts.ToArray(), unresolved.ToArray(), text, evidence, special.ToArray(), declared);
    }

    public static bool ValidateParserFacts(IReadOnlyList<HealthFact> facts, IReadOnlyDictionary<string, string> sources,
        IReadOnlyList<NutritionConcept> concepts) => facts.Count is > 0 and <= 40 && facts.All(f =>
        f is not null && f.Kind is "condition" or "symptom" or "food_allergy" or "dietary_instruction" or "eating_ability" &&
        f.Assertion is "present" or "absent" or "uncertain" && f.Temporality is "current" or "past" or "unknown" &&
        f.Subject == "beneficiary" && !string.IsNullOrWhiteSpace(f.Label) &&
        !string.IsNullOrWhiteSpace(f.Code) && !string.IsNullOrWhiteSpace(f.SourceKey) &&
        f.Quote is { Length: > 0 and <= 4000 } && sources.TryGetValue(f.SourceKey, out var source) &&
        source.IndexOf(f.Quote, StringComparison.Ordinal) >= 0 &&
        source.IndexOf(f.Quote, StringComparison.Ordinal) == source.LastIndexOf(f.Quote, StringComparison.Ordinal) &&
        concepts.Any(c => c.Kind == f.Kind && c.Code == f.Code &&
            (f.Quote.Contains(c.Code, StringComparison.OrdinalIgnoreCase) ||
             c.Aliases.Any(a => !string.IsNullOrWhiteSpace(a) && f.Quote.Contains(a, StringComparison.OrdinalIgnoreCase)))));
}
