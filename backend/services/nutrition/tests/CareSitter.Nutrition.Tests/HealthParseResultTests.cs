using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class HealthParseResultTests
{
    private static readonly NutritionConcept[] Concepts =
    [
        new("HYPERTENSION", "condition", ["tăng huyết áp"], 1),
        new("GOUT", "condition", ["gout"], 1)
    ];

    [Fact]
    public void Exact_offsets_allow_repeated_quotes_and_preserve_other_subject()
    {
        const string source = "Bố bị gout. Beni tăng huyết áp; trước đây đã nghe về tăng huyết áp.";
        var request = Request(source);
        var beneficiaryStart = source.IndexOf("tăng huyết áp", StringComparison.Ordinal);
        var otherStart = source.IndexOf("gout", StringComparison.Ordinal);
        var result = new HealthParseResult(1, 12,
        [
            Fact("GOUT", "gout", "other", otherStart),
            Fact("HYPERTENSION", "tăng huyết áp", "beneficiary", beneficiaryStart)
        ], [], []);

        Assert.True(HealthParseResultValidator.TryValidate(request, result, out var facts));
        Assert.Equal(["other", "beneficiary"], facts.Select(fact => fact.Subject).ToArray());
    }

    [Fact]
    public void Zero_facts_are_valid_when_every_source_is_explicitly_irrelevant()
    {
        var request = Request("Beni thích nghe nhạc buổi sáng.");
        var result = new HealthParseResult(1, 12, [], [], ["generalNote"]);

        Assert.True(HealthParseResultValidator.TryValidate(request, result, out var facts));
        Assert.Empty(facts);
    }

    [Fact]
    public void Fabricated_span_unknown_concept_and_unaccounted_source_are_rejected()
    {
        var request = Request("Beni tăng huyết áp.");
        var validStart = request.Sources["generalNote"].IndexOf("tăng huyết áp", StringComparison.Ordinal);
        var fabricated = new HealthParseResult(1, 12,
            [Fact("HYPERTENSION", "tăng huyết áp", "beneficiary", validStart + 1)], [], []);
        var unknown = new HealthParseResult(1, 12,
            [Fact("UNKNOWN", "tăng huyết áp", "beneficiary", validStart)], [], []);
        var unaccounted = new HealthParseResult(1, 12, [], [], []);

        Assert.False(HealthParseResultValidator.TryValidate(request, fabricated, out _));
        Assert.False(HealthParseResultValidator.TryValidate(request, unknown, out _));
        Assert.False(HealthParseResultValidator.TryValidate(request, unaccounted, out _));
    }

    [Fact]
    public void Ambiguous_subject_is_unresolved_instead_of_becoming_a_fact()
    {
        const string source = "Nhà có người bị gout.";
        var start = source.IndexOf("người bị gout", StringComparison.Ordinal);
        var request = Request(source);
        var unresolved = new HealthUnresolvedStatement("generalNote", "người bị gout", start,
            start + "người bị gout".Length, "ambiguous_subject");
        var result = new HealthParseResult(1, 12, [], [unresolved], []);

        Assert.True(HealthParseResultValidator.TryValidate(request, result, out var facts));
        Assert.Empty(facts);
        Assert.Equal(["textSources/generalNote/7"], HealthParseResultValidator.UnresolvedFields(result));
    }

    [Fact]
    public void Other_person_condition_does_not_conflict_with_a_healthy_beneficiary_declaration()
    {
        var snapshot = EligibilityTests.Healthy();
        var health = HealthSnapshotNormalizer.Normalize(snapshot, []);
        var other = new HealthFact("condition", "GOUT", "Gout", "present", "current",
            "generalNote", "Bố bị gout", "other");

        var decision = NutritionEligibilityPolicy.Evaluate(snapshot, health, [other], [], false);

        Assert.Equal("awaiting_confirmation", decision.State);
        Assert.Empty(decision.Conflicts);
    }

    [Fact]
    public void Alias_validation_accepts_equivalent_vietnamese_text_without_diacritics()
    {
        const string source = "Beni bi tang huyet ap.";
        var start = source.IndexOf("tang huyet ap", StringComparison.Ordinal);
        var request = Request(source);
        var result = new HealthParseResult(1, 12,
            [Fact("HYPERTENSION", "tang huyet ap", "beneficiary", start)], [], []);

        Assert.True(HealthParseResultValidator.TryValidate(request, result, out var facts));
        Assert.Single(facts);
    }

    private static HealthParseRequest Request(string source) => new(1, 12,
        new Dictionary<string, string> { ["generalNote"] = source }, Concepts,
        HealthKnowledgeGraphRetriever.Retrieve(12,
            new Dictionary<string, string> { ["generalNote"] = source }, Concepts, []));

    private static HealthParseFact Fact(string code, string quote, string subject, int start) =>
        new("condition", code, code, "present", "current", "generalNote", quote, subject, start, start + quote.Length);
}
