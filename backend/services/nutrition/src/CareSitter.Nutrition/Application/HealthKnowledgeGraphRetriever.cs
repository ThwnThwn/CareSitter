using System.Globalization;
using System.Text;
using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

/// <summary>
/// Builds a bounded local-search subgraph from the versioned Nutrition catalog.
/// The graph is retrieval context only; it never creates patient facts or policy decisions.
/// </summary>
public static class HealthKnowledgeGraphRetriever
{
    public const int SchemaVersion = 1;
    public const string Strategy = "catalog-local-exact-alias-v1";
    private const int MaximumConcepts = 32;
    private const int MaximumNodes = 96;
    private const int MaximumEdges = 64;
    private const int MaximumAliasesPerNode = 4;
    private const int MaximumAliasLength = 100;
    private static readonly IReadOnlySet<string> ParserKinds = new HashSet<string>(StringComparer.Ordinal)
    {
        "condition", "symptom", "food_allergy", "dietary_instruction", "eating_ability"
    };

    public static HealthKnowledgeGraphContext Retrieve(long revision, IReadOnlyDictionary<string, string> sources,
        IReadOnlyList<NutritionConcept> concepts, IReadOnlyList<DietaryRule> publishedRules)
    {
        ArgumentNullException.ThrowIfNull(sources);
        ArgumentNullException.ThrowIfNull(concepts);
        ArgumentNullException.ThrowIfNull(publishedRules);
        if (revision < 0) throw new ArgumentOutOfRangeException(nameof(revision));

        var searchable = string.Join('\n', sources.OrderBy(pair => pair.Key, StringComparer.Ordinal)
            .Select(pair => Normalize(pair.Value)));
        var candidates = concepts
            .Where(concept => ParserKinds.Contains(concept.Kind))
            .Select(concept => (Concept: concept, Score: MatchScore(searchable, concept)))
            .Where(candidate => candidate.Score > 0)
            .OrderByDescending(candidate => candidate.Score)
            .ThenBy(candidate => candidate.Concept.Kind, StringComparer.Ordinal)
            .ThenBy(candidate => candidate.Concept.Code, StringComparer.Ordinal)
            .Take(MaximumConcepts)
            .Select(candidate => candidate.Concept)
            .ToArray();

        var nodes = new Dictionary<string, HealthKnowledgeGraphNode>(StringComparer.Ordinal);
        var edges = new List<HealthKnowledgeGraphEdge>();
        foreach (var concept in candidates)
        {
            var conceptId = ConceptId(concept.Kind, concept.Code);
            nodes[conceptId] = new(conceptId, "concept", concept.Kind, concept.Code,
                AliasesForContext(searchable, concept));

            foreach (var rule in publishedRules.Where(rule =>
                         string.Equals(rule.ConditionCode, concept.Code, StringComparison.Ordinal)).Take(MaximumEdges))
            {
                var policyId = $"policy:{concept.Code}";
                if (!nodes.ContainsKey(policyId) && nodes.Count >= MaximumNodes) break;
                nodes.TryAdd(policyId, new(policyId, "policy", "dietary_rule", concept.Code, []));
                var evidenceSources = rule.Sources.Where(source => !string.IsNullOrWhiteSpace(source) && source.Length <= 200)
                    .Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).Take(16).ToArray();
                AddEdge(edges, new(conceptId, policyId, "governed_by", evidenceSources));
                foreach (var sourceId in evidenceSources)
                {
                    if (edges.Count >= MaximumEdges) break;
                    var evidenceId = $"evidence:{sourceId}";
                    if (!nodes.ContainsKey(evidenceId) && nodes.Count >= MaximumNodes) break;
                    nodes.TryAdd(evidenceId, new(evidenceId, "evidence", "citation", sourceId, []));
                    AddEdge(edges, new(policyId, evidenceId, "supported_by", [sourceId]));
                }
            }
        }

        return new(SchemaVersion, revision, Strategy, nodes.Values.OrderBy(node => node.Id, StringComparer.Ordinal).ToArray(),
            edges.OrderBy(edge => edge.From, StringComparer.Ordinal).ThenBy(edge => edge.To, StringComparer.Ordinal)
                .ThenBy(edge => edge.Relation, StringComparer.Ordinal).ToArray());
    }

    private static string ConceptId(string kind, string code) => $"concept:{kind}:{code}";

    public static bool IsValid(HealthKnowledgeGraphContext? graph, long revision)
    {
        if (graph is null || graph.SchemaVersion != SchemaVersion || graph.Revision != revision ||
            graph.RetrievalStrategy != Strategy || graph.Nodes is null || graph.Edges is null ||
            graph.Nodes.Length > MaximumNodes || graph.Edges.Length > MaximumEdges ||
            graph.Nodes.Any(node => node is null || string.IsNullOrWhiteSpace(node.Id) || node.Id.Length > 200 ||
                string.IsNullOrWhiteSpace(node.Type) || node.Type.Length > 40 || string.IsNullOrWhiteSpace(node.Kind) ||
                node.Kind.Length > 100 || string.IsNullOrWhiteSpace(node.Code) || node.Code.Length > 200 ||
                (node.Type == "concept" && node.Id != ConceptId(node.Kind, node.Code)) ||
                node.Aliases is null || node.Aliases.Length > MaximumAliasesPerNode ||
                node.Aliases.Any(alias => string.IsNullOrWhiteSpace(alias) || alias.Length > MaximumAliasLength)) ||
            graph.Nodes.Select(node => node.Id).Distinct(StringComparer.Ordinal).Count() != graph.Nodes.Length)
            return false;
        var nodeIds = graph.Nodes.Select(node => node.Id).ToHashSet(StringComparer.Ordinal);
        return graph.Edges.All(edge => edge is not null && nodeIds.Contains(edge.From) && nodeIds.Contains(edge.To) &&
            !string.IsNullOrWhiteSpace(edge.Relation) && edge.Relation.Length <= 100 && edge.EvidenceSourceIds is not null &&
            edge.EvidenceSourceIds.Length <= 16 && edge.EvidenceSourceIds.All(source =>
                !string.IsNullOrWhiteSpace(source) && source.Length <= 200));
    }

    internal static bool Mentions(NutritionConcept concept, string text)
    {
        var normalized = Normalize(text);
        return concept.Aliases.Append(concept.Code).Where(term => !string.IsNullOrWhiteSpace(term))
            .Select(Normalize).Any(term => term.Length > 1 && normalized.Contains(term, StringComparison.Ordinal));
    }

    private static void AddEdge(ICollection<HealthKnowledgeGraphEdge> edges, HealthKnowledgeGraphEdge edge)
    {
        if (edges.Count >= MaximumEdges || edges.Any(existing => existing.From == edge.From && existing.To == edge.To &&
                existing.Relation == edge.Relation)) return;
        edges.Add(edge);
    }

    private static int MatchScore(string searchable, NutritionConcept concept) => concept.Aliases
        .Append(concept.Code)
        .Where(term => !string.IsNullOrWhiteSpace(term))
        .Select(Normalize)
        .Where(term => term.Length > 1 && searchable.Contains(term, StringComparison.Ordinal))
        .DefaultIfEmpty("")
        .Max(term => term.Length);

    private static string[] AliasesForContext(string searchable, NutritionConcept concept) => concept.Aliases
        .Where(alias => !string.IsNullOrWhiteSpace(alias) && alias.Length <= MaximumAliasLength)
        .Distinct(StringComparer.OrdinalIgnoreCase)
        .OrderByDescending(alias => searchable.Contains(Normalize(alias), StringComparison.Ordinal))
        .ThenBy(alias => alias, StringComparer.OrdinalIgnoreCase)
        .Take(MaximumAliasesPerNode)
        .ToArray();

    private static string Normalize(string value)
    {
        var decomposed = value.Normalize(NormalizationForm.FormD);
        var result = new StringBuilder(decomposed.Length);
        var previousSpace = true;
        foreach (var character in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark) continue;
            var normalized = char.ToLowerInvariant(character == 'đ' || character == 'Đ' ? 'd' : character);
            if (char.IsLetterOrDigit(normalized) || normalized == '_')
            {
                result.Append(normalized); previousSpace = false;
            }
            else if (!previousSpace)
            {
                result.Append(' '); previousSpace = true;
            }
        }
        return result.ToString().Trim();
    }
}
