using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

// Port of keyword_retriever._LexicalIndex + retrievers.KeywordRetriever.
internal sealed class KeywordMealKnowledgeIndex
{
    private readonly Document[] _documents;
    private readonly Dictionary<string, double> _idf;
    private readonly double _averageBody;
    private readonly double _averageHeading;

    public KeywordMealKnowledgeIndex(byte[] corpus)
    {
        var documents = new List<Document>();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var line in Encoding.UTF8.GetString(corpus).Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            using var json = JsonDocument.Parse(line);
            var chunk = json.RootElement;
            var id = chunk.GetProperty("chunk_id").GetString() ?? "";
            if (id.Length == 0 || !seen.Add(id)) throw new InvalidOperationException("Invalid corpus ID.");
            if (!chunk.TryGetProperty("index_eligible", out var eligible) || eligible.ValueKind != JsonValueKind.True) continue;
            if (chunk.GetProperty("review_status").GetString() != "ready_for_retrieval_eval")
                throw new InvalidOperationException("Invalid eligible chunk review status.");
            var text = chunk.GetProperty("text").GetString() ?? "";
            if (string.IsNullOrWhiteSpace(text)) throw new InvalidOperationException("Empty eligible chunk.");
            var headings = chunk.GetProperty("headings").ValueKind == JsonValueKind.Null ? [] :
                chunk.GetProperty("headings").EnumerateArray().Select(x => x.GetString() ?? "").ToArray();
            var body = Tokens(text);
            var heading = Tokens(string.Join(' ', headings));
            var title = headings.LastOrDefault(x => x.Length > 0) ?? "Tài liệu dinh dưỡng";
            var chapter = headings.FirstOrDefault(x => x.Length > 0);
            var printed = chunk.TryGetProperty("printed_page", out var page) && page.ValueKind != JsonValueKind.Null ? page.ToString() : null;
            var locator = chunk.GetProperty("source_locator").GetString() ?? "";
            var sourceTitle = (chunk.TryGetProperty("source_id", out var source) ? source.GetString() : null) switch
            {
                "vdd-ten-nutrition-recommendations-2030-en" => "Ten Recommendations for Proper Nutrition toward 2030 — Ministry of Health",
                "who-fao-healthy-diets-2024" => "What are healthy diets? — WHO/FAO, 2024",
                "who-europe-healthy-ageing-diets-2023" => "Promoting physical activity and healthy diets for healthy ageing — WHO Europe, 2023",
                _ => "Dinh dưỡng lâm sàng — Viện Dinh dưỡng, 2019"
            };
            var pageReference = printed is { Length: > 0 } ? $"trang {printed}" :
                chunk.TryGetProperty("pdf_page", out var pdf) && pdf.ValueKind == JsonValueKind.Number ? $"PDF trang {pdf.GetInt32()}" : locator;
            var evidence = new MealRecommendationEvidence(id, title, chapter, printed, locator,
                $"{sourceTitle}, {pageReference}", text.Trim()[..Math.Min(text.Trim().Length, 1600)]) { SourceTitle = sourceTitle };
            documents.Add(new(id, chunk.GetProperty("source_revision_id").GetString() ?? "", evidence,
                Counts(body), Counts(heading), body.Length, heading.Length));
        }
        if (documents.Count == 0) throw new InvalidOperationException("Corpus has no eligible chunks.");
        _documents = documents.ToArray();
        _averageBody = _documents.Average(d => d.BodyLength);
        _averageHeading = Math.Max(1, _documents.Average(d => d.HeadingLength));
        _idf = _documents.SelectMany(d => d.Body.Keys.Union(d.Heading.Keys)).GroupBy(x => x)
            .ToDictionary(g => g.Key, g => Math.Log(1 + (_documents.Length - g.Count() + 0.5) / (g.Count() + 0.5)));
    }

    public MealRecommendationEvidence[] Search(string question, int topK, double minimum,
        string? sourceRevision = null, bool editionGuard = false, CancellationToken ct = default)
    {
        if (question.EnumerateRunes().Count() > 500 || topK is < 1 or > 100 || !double.IsFinite(minimum) || minimum is < 0 or > 10000)
            throw new InvalidOperationException("Invalid keyword query or threshold.");
        if (editionGuard && !AcceptEdition(question, sourceRevision ?? "")) return [];
        var tokens = Tokens(question).Distinct(StringComparer.Ordinal).ToArray();
        return _documents.Select(document =>
        {
            ct.ThrowIfCancellationRequested();
            double score = 0;
            foreach (var token in tokens)
            {
                var idf = _idf.GetValueOrDefault(token);
                score += Bm25(document.Body.GetValueOrDefault(token), document.BodyLength, _averageBody, idf);
                score += 2.5 * Bm25(document.Heading.GetValueOrDefault(token), document.HeadingLength, _averageHeading, idf);
            }
            return (Document: document, Score: score);
        }).Where(x => x.Score > 0).OrderByDescending(x => x.Score)
          .ThenBy(x => x.Document.Id, StringComparer.Ordinal)
          .Where(x => Math.Round(x.Score, 6, MidpointRounding.ToEven) >= minimum &&
              (sourceRevision is null || x.Document.Revision == sourceRevision))
          .Take(topK).Select(x => x.Document.Evidence).ToArray();
    }

    internal static string Fold(string value)
    {
        var decomposed = value.Replace('đ', 'd').Replace('Đ', 'D').ToLowerInvariant().Normalize(NormalizationForm.FormD);
        return string.Concat(decomposed.EnumerateRunes().Where(r => Rune.GetUnicodeCategory(r) != UnicodeCategory.NonSpacingMark));
    }

    internal static string[] Tokens(string value) => Regex.Matches(Fold(value), "[a-z0-9_]+", RegexOptions.CultureInvariant).Select(m => m.Value).ToArray();
    private static Dictionary<string, int> Counts(string[] values) => values.GroupBy(x => x).ToDictionary(g => g.Key, g => g.Count());
    private static double Bm25(int frequency, int length, double average, double idf) => frequency == 0 ? 0 :
        idf * frequency * 2.2 / (frequency + 1.2 * (0.25 + 0.75 * length / average));

    private static bool AcceptEdition(string question, string revision)
    {
        var folded = Fold(question);
        if (!Regex.IsMatch(folded, @"\b(?:ban cap nhat|ban sua doi|phien ban|an ban|tai ban|edition|revision|updated edition|revised edition|latest edition|current edition)\b")) return true;
        var source = Regex.Match(revision.Split('@')[0], @"(?:^|[-_])((?:19|20)\d{2})$");
        var years = Regex.Matches(folded, @"\b(?:19|20)\d{2}\b");
        return source.Success && years.Count > 0 && years.All(y => y.Value == source.Groups[1].Value);
    }

    private sealed record Document(string Id, string Revision, MealRecommendationEvidence Evidence,
        Dictionary<string, int> Body, Dictionary<string, int> Heading, int BodyLength, int HeadingLength);
}
