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
                    if (item.EnumerateObject().Any(p => p.Name is not ("label" or "code" or "assertion" or "temporality")) ||
                        item.EnumerateObject().Select(p => p.Name).Distinct().Count() != item.EnumerateObject().Count() ||
                        item.EnumerateObject().Any(p => p.Value.ValueKind != JsonValueKind.String))
                    { unresolved.Add(pointer); continue; }
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
            if (nutrition.EnumerateObject().Select(p => p.Name).Distinct().Count() != nutrition.EnumerateObject().Count())
                unresolved.Add("healthHistory/nutrition");
            var known = new HashSet<string> { "schemaVersion", "conditionsStatus", "medicationsStatus", "feedingRoute", "swallowingStatus", "fluidRestriction", "electrolyteRestriction", "dietaryPattern", "nutritionGoal", "guidance", "symptoms" };
            foreach (var prop in nutrition.EnumerateObject())
            {
                if (!known.Contains(prop.Name)) { unresolved.Add("healthHistory/nutrition/" + prop.Name); continue; }
                if (prop.Name == "schemaVersion") { if (prop.Value.GetRawText() != "1") unresolved.Add("healthHistory/nutrition/schemaVersion"); continue; }
                if (prop.Value.ValueKind != JsonValueKind.String) { unresolved.Add("healthHistory/nutrition/" + prop.Name); continue; }
                var v = prop.Value.GetString()!; evidence[prop.Name] = v;
                var valid = prop.Name switch
                {
                    "conditionsStatus" or "medicationsStatus" => v is "reported_none" or "reported_present",
                    "feedingRoute" => v is "oral" or "tube",
                    "swallowingStatus" => v is "normal" or "difficulty",
                    "fluidRestriction" or "electrolyteRestriction" => v is "none" or "present",
                    "dietaryPattern" => v is "regular" or "vegetarian",
                    "nutritionGoal" => v is "maintain" or "gain" or "lose",
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
        if (source.Medications is { ValueKind: not JsonValueKind.Null } medications)
        {
            if (medications.ValueKind != JsonValueKind.Array || medications.GetArrayLength() > 40) unresolved.Add("medications");
            else
            {
                var index = 0;
                foreach (var medication in medications.EnumerateArray())
                {
                    var pointer = $"medications/{index++}";
                    if (medication.ValueKind != JsonValueKind.Object ||
                        medication.EnumerateObject().Select(p => p.Name).Distinct().Count() != medication.EnumerateObject().Count() ||
                        medication.EnumerateObject().Any(p => p.Name is not ("name" or "dosage" or "schedule" or "instruction" or "start_date" or "end_date" or "is_active")) ||
                        !medication.TryGetProperty("name", out var name) || name.ValueKind != JsonValueKind.String ||
                        string.IsNullOrWhiteSpace(name.GetString()) || name.GetString()!.Length > 200 ||
                        medication.EnumerateObject().Any(p => p.Name != "is_active" && p.Value.ValueKind is not (JsonValueKind.String or JsonValueKind.Null)))
                    { unresolved.Add(pointer); continue; }
                    if (!medication.TryGetProperty("is_active", out var active) || active.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                    { unresolved.Add(pointer + "/is_active"); continue; }
                    if (active.GetBoolean()) evidence["activeMedications"] = "present";
                }
            }
        }
        return new(facts.ToArray(), unresolved.ToArray(), text, evidence, special.ToArray(), declared);
    }

}
