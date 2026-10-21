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
                Facts = result.Facts.Select(fact => fact with
                {
                    Quote = Restore(fact.SourceKey, fact.Quote, fact.StartOffset, fact.EndOffset,
                        request.Sources, redacted)
                }).ToArray(),
                UnresolvedStatements = result.UnresolvedStatements.Select(statement => statement with
                {
                    Quote = Restore(statement.SourceKey, statement.Quote, statement.StartOffset,
                        statement.EndOffset, request.Sources, redacted)
                }).ToArray()
            };
        }
        catch (HealthParserException) { throw; }
        catch (Exception error) when (error is JsonException or InvalidOperationException or ArgumentOutOfRangeException)
        {
            throw new HealthParserException("nutrition.ai_invalid_output", false);
        }
    }

    private static string Restore(string sourceKey, string quote, int start, int end,
        IReadOnlyDictionary<string, string> original, IReadOnlyDictionary<string, string> redacted)
    {
        if (!original.TryGetValue(sourceKey, out var raw) || !redacted.TryGetValue(sourceKey, out var safe) ||
            start < 0 || end <= start || end > raw.Length || end > safe.Length || end - start != quote.Length ||
            !safe.AsSpan(start, quote.Length).SequenceEqual(quote.AsSpan()))
            throw new HealthParserException("nutrition.ai_invalid_output", false);
        return raw.Substring(start, end - start);
    }
}
