using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Tests;

public sealed class HealthKnowledgeGraphRetrieverTests
{
    private static readonly NutritionConcept[] Concepts =
    [
        new("HYPERTENSION", "condition", ["Tăng huyết áp", "Cao huyết áp"], 1),
        new("GOUT", "condition", ["Gút", "Gout"], 1),
        new("RICE_WHITE_RAW", "ingredient", ["Gạo tẻ"], 1)
    ];

    [Fact]
    public void Local_search_is_case_and_diacritic_insensitive_and_bounded_to_parser_concepts()
    {
        var graph = HealthKnowledgeGraphRetriever.Retrieve(17,
            new Dictionary<string, string> { ["note"] = "BENI BI CAO HUYET AP, thích gạo tẻ." }, Concepts, []);

        var node = Assert.Single(graph.Nodes);
        Assert.Equal("concept:condition:HYPERTENSION", node.Id);
        Assert.Equal(HealthKnowledgeGraphRetriever.Strategy, graph.RetrievalStrategy);
        Assert.Equal(17, graph.Revision);
        Assert.Empty(graph.Edges);
    }

    [Fact]
    public void Local_search_expands_a_matching_condition_to_published_policy_evidence()
    {
        var rule = new DietaryRule(Guid.NewGuid(), "HYPERTENSION", [], [], new(),
            ["VIEN_DINH_DUONG_2019", "MOH_HTN_GUIDE_2010"]);

        var graph = HealthKnowledgeGraphRetriever.Retrieve(21,
            new Dictionary<string, string> { ["note"] = "Beni tăng huyết áp." }, Concepts, [rule]);

        Assert.Contains(graph.Nodes, node => node.Id == "concept:condition:HYPERTENSION");
        Assert.Contains(graph.Nodes, node => node.Id == "policy:HYPERTENSION");
        Assert.Contains(graph.Nodes, node => node.Id == "evidence:MOH_HTN_GUIDE_2010");
        Assert.Contains(graph.Edges, edge => edge.From == "concept:condition:HYPERTENSION" &&
            edge.To == "policy:HYPERTENSION" && edge.Relation == "governed_by");
        Assert.Contains(graph.Edges, edge => edge.From == "policy:HYPERTENSION" &&
            edge.To == "evidence:VIEN_DINH_DUONG_2019" && edge.Relation == "supported_by");
    }

    [Fact]
    public void Validator_rejects_a_dictionary_concept_missing_from_retrieved_graph()
    {
        const string source = "Beni bị gout.";
        var start = source.IndexOf("gout", StringComparison.Ordinal);
        var graph = new HealthKnowledgeGraphContext(1, 12, HealthKnowledgeGraphRetriever.Strategy,
            [new("concept:condition:HYPERTENSION", "concept", "condition", "HYPERTENSION", ["Tăng huyết áp"])], []);
        var request = new HealthParseRequest(1, 12, new Dictionary<string, string> { ["note"] = source }, Concepts, graph);
        var result = new HealthParseResult(1, 12,
            [new("condition", "GOUT", "Gout", "present", "current", "note", "gout", "beneficiary", start, start + 4)], [], []);

        Assert.False(HealthParseResultValidator.TryValidate(request, result, out _));
    }
}
