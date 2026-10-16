using CareSitter.Nutrition.Domain;

namespace CareSitter.Nutrition.Application;

public static class HealthParseResultValidator
{
    public const int SchemaVersion = 1;
    private const int MaximumItems = 40;
    private static readonly IReadOnlySet<string> Kinds = new HashSet<string>(StringComparer.Ordinal)
        { "condition", "symptom", "food_allergy", "dietary_instruction", "eating_ability" };
    private static readonly IReadOnlySet<string> Reasons = new HashSet<string>(StringComparer.Ordinal)
    {
        "unknown_concept", "ambiguous_subject", "ambiguous_assertion", "ambiguous_temporality",
        "insufficient_detail", "unsupported_statement"
    };

    public static bool TryValidate(HealthParseRequest request, HealthParseResult result, out HealthFact[] facts)
    {
        facts = [];
        if (request.SchemaVersion != SchemaVersion || result.SchemaVersion != request.SchemaVersion ||
            request.DictionaryRevision < 0 || result.DictionaryRevision != request.DictionaryRevision ||
            request.Sources is null || request.Concepts is null || result.Facts is null ||
            !HealthKnowledgeGraphRetriever.IsValid(request.Graph, request.DictionaryRevision) ||
            result.UnresolvedStatements is null || result.IrrelevantSourceKeys is null ||
            result.Facts.Length > MaximumItems || result.UnresolvedStatements.Length > MaximumItems ||
            result.IrrelevantSourceKeys.Length > request.Sources.Count ||
            result.IrrelevantSourceKeys.Distinct(StringComparer.Ordinal).Count() != result.IrrelevantSourceKeys.Length)
            return false;

        var irrelevant = result.IrrelevantSourceKeys.ToHashSet(StringComparer.Ordinal);
        if (irrelevant.Any(key => !request.Sources.ContainsKey(key))) return false;

        var mapped = new List<HealthFact>(result.Facts.Length);
        foreach (var fact in result.Facts)
        {
            if (fact is null || !Kinds.Contains(fact.Kind) || fact.Assertion is not ("present" or "absent" or "uncertain") ||
                fact.Temporality is not ("current" or "past" or "unknown") || fact.Subject is not ("beneficiary" or "other") ||
                string.IsNullOrWhiteSpace(fact.Code) || fact.Code.Length > 100 || string.IsNullOrWhiteSpace(fact.Label) ||
                fact.Label.Length > 200 || !ValidSpan(request.Sources, fact.SourceKey, fact.Quote, fact.StartOffset, fact.EndOffset) ||
                irrelevant.Contains(fact.SourceKey) || !request.Graph.Nodes.Any(node => node.Type == "concept" &&
                    node.Kind == fact.Kind && node.Code == fact.Code) ||
                !request.Concepts.Any(concept => concept.Kind == fact.Kind && concept.Code == fact.Code &&
                    HealthKnowledgeGraphRetriever.Mentions(concept, fact.Quote)))
                return false;
            mapped.Add(new HealthFact(fact.Kind, fact.Code, fact.Label, fact.Assertion, fact.Temporality,
                fact.SourceKey, fact.Quote, fact.Subject));
        }

        foreach (var unresolved in result.UnresolvedStatements)
            if (unresolved is null || !Reasons.Contains(unresolved.Reason) ||
                !ValidSpan(request.Sources, unresolved.SourceKey, unresolved.Quote, unresolved.StartOffset, unresolved.EndOffset) ||
                irrelevant.Contains(unresolved.SourceKey)) return false;

        if (result.Facts.Select(FactIdentity).Distinct().Count() != result.Facts.Length ||
            result.UnresolvedStatements.Select(UnresolvedIdentity).Distinct().Count() != result.UnresolvedStatements.Length)
            return false;

        var accounted = result.Facts.Select(f => f.SourceKey)
            .Concat(result.UnresolvedStatements.Select(statement => statement.SourceKey))
            .Concat(result.IrrelevantSourceKeys).ToHashSet(StringComparer.Ordinal);
        if (request.Sources.Keys.Any(key => !accounted.Contains(key))) return false;

        facts = mapped.ToArray();
        return true;
    }

    public static string[] UnresolvedFields(HealthParseResult result) => result.UnresolvedStatements
        .Select(statement => $"textSources/{statement.SourceKey}/{statement.StartOffset}")
        .Distinct(StringComparer.Ordinal).ToArray();

    private static bool ValidSpan(IReadOnlyDictionary<string, string> sources, string sourceKey, string quote,
        int startOffset, int endOffset) => !string.IsNullOrWhiteSpace(sourceKey) && quote is { Length: > 0 and <= 4000 } &&
        sources.TryGetValue(sourceKey, out var source) && startOffset >= 0 && endOffset > startOffset &&
        endOffset <= source.Length && endOffset - startOffset == quote.Length &&
        source.AsSpan(startOffset, quote.Length).SequenceEqual(quote.AsSpan());

    private static string FactIdentity(HealthParseFact fact) =>
        $"{fact.Kind}\u001f{fact.Code}\u001f{fact.Assertion}\u001f{fact.Temporality}\u001f{fact.Subject}\u001f{fact.SourceKey}\u001f{fact.StartOffset}\u001f{fact.EndOffset}";

    private static string UnresolvedIdentity(HealthUnresolvedStatement statement) =>
        $"{statement.SourceKey}\u001f{statement.StartOffset}\u001f{statement.EndOffset}\u001f{statement.Reason}";
}
