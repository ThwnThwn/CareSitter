using System.Text.Json;
using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

internal static class HealthParserResponse
{
    public static HealthParseResult Parse(string output, HealthParseRequest request,
        IReadOnlyDictionary<string, string> redacted)
    {
        try
        {
            var result = NutritionJson.Read<HealthParseResult>(output);
            if (result.Facts is null || result.UnresolvedStatements is null || result.IrrelevantSourceKeys is null)
                throw new HealthParserException("nutrition.ai_invalid_output", false);
            return result with
            {
                Facts = result.Facts.Select(fact => Repair(fact, request.Sources, redacted)).ToArray(),
                UnresolvedStatements = result.UnresolvedStatements
                    .Select(statement => Repair(statement, request.Sources, redacted)).ToArray()
            };
        }
        catch (HealthParserException) { throw; }
        catch (Exception error) when (error is JsonException or InvalidOperationException or ArgumentOutOfRangeException)
        {
            throw new HealthParserException("nutrition.ai_invalid_output", false);
        }
    }

    private static HealthParseFact Repair(HealthParseFact fact, IReadOnlyDictionary<string, string> original,
        IReadOnlyDictionary<string, string> redacted)
    {
        var span = Restore(fact.SourceKey, fact.Quote, fact.StartOffset, fact.EndOffset, original, redacted);
        return fact with { Quote = span.Quote, StartOffset = span.Start, EndOffset = span.End };
    }

    private static HealthUnresolvedStatement Repair(HealthUnresolvedStatement statement,
        IReadOnlyDictionary<string, string> original, IReadOnlyDictionary<string, string> redacted)
    {
        var span = Restore(statement.SourceKey, statement.Quote, statement.StartOffset, statement.EndOffset,
            original, redacted);
        return statement with { Quote = span.Quote, StartOffset = span.Start, EndOffset = span.End };
    }

    private static (string Quote, int Start, int End) Restore(string sourceKey, string quote, int start, int end,
        IReadOnlyDictionary<string, string> original, IReadOnlyDictionary<string, string> redacted)
    {
        if (!original.TryGetValue(sourceKey, out var raw) || !redacted.TryGetValue(sourceKey, out var safe) ||
            string.IsNullOrWhiteSpace(quote) || quote.Length > 4000)
            throw new HealthParserException("nutrition.ai_invalid_output", false);

        var exact = start >= 0 && end > start && end <= raw.Length && end <= safe.Length &&
                    end - start == quote.Length && safe.AsSpan(start, quote.Length).SequenceEqual(quote.AsSpan());
        if (!exact)
        {
            start = safe.IndexOf(quote, StringComparison.Ordinal);
            if (start < 0 || safe.IndexOf(quote, start + quote.Length, StringComparison.Ordinal) >= 0)
                throw new HealthParserException("nutrition.ai_invalid_output", false);
            end = start + quote.Length;
        }

        return (raw.Substring(start, end - start), start, end);
    }
}
