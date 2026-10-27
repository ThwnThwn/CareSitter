using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.Nutrition;

public sealed class NutritionKnowledgeOptions
{
    public bool Enabled { get; set; }
    public string CorpusPath { get; set; } = "";
    public string CorpusSha256 { get; set; } = "";
}

public sealed record NutritionKnowledgeHitResponse(
    string ChunkId, string Heading, string Excerpt, int PdfPage, string? PrintedPage,
    string SourceTitle, string SourceRevisionId);

public sealed record NutritionKnowledgeSearchResponse(
    string Query, IReadOnlyList<NutritionKnowledgeHitResponse> Results);

[ApiController, Authorize(Roles = "CUSTOMER")]
[Route("api/v1/nutrition/knowledge")]
public sealed class NutritionKnowledgeController(NutritionKnowledgeSearch search) : ControllerBase
{
    [HttpGet]
    public IActionResult Get([FromQuery] string? q)
    {
        if (!search.Enabled) return NotFound();
        var query = q?.Trim() ?? "";
        if (query.Length is < 3 or > 160)
            return BadRequest(new { code = "NUTRITION_KNOWLEDGE_QUERY_INVALID", message = "Nhập từ 3 đến 160 ký tự để tra cứu." });
        try
        {
            return Ok(new NutritionKnowledgeSearchResponse(query, search.Find(query)));
        }
        catch (InvalidOperationException)
        {
            return StatusCode(503, new { code = "NUTRITION_KNOWLEDGE_UNAVAILABLE", message = "Chưa tải được tài liệu dinh dưỡng." });
        }
    }
}

public sealed class NutritionKnowledgeSearch
{
    private const string SourceId = "book-dinh-duong-lam-sang-2019";
    private const string SourceTitle = "Dinh dưỡng lâm sàng — Viện Dinh dưỡng, 2019";
    private readonly NutritionKnowledgeOptions _options;
    private readonly Lazy<IReadOnlyList<Document>> _documents;

    public NutritionKnowledgeSearch(IOptions<NutritionKnowledgeOptions> options)
    {
        _options = options.Value;
        _documents = new Lazy<IReadOnlyList<Document>>(Load);
    }

    public bool Enabled => _options.Enabled;

    public IReadOnlyList<NutritionKnowledgeHitResponse> Find(string question)
    {
        var documents = _documents.Value;
        var query = Tokens(question).Distinct().ToArray();
        if (query.Length == 0) return [];
        var count = documents.Count;
        var averageBody = documents.Average(x => x.BodyLength);
        var averageHeading = Math.Max(1, documents.Average(x => x.HeadingLength));
        var matches = new List<(Document Document, double Score)>();
        foreach (var document in documents)
        {
            double score = 0;
            foreach (var token in query)
            {
                var frequency = documents.Count(x => x.Body.ContainsKey(token) || x.Heading.ContainsKey(token));
                if (frequency == 0) continue;
                var idf = Math.Log(1 + (count - frequency + 0.5) / (frequency + 0.5));
                score += Bm25(document.Body.GetValueOrDefault(token), document.BodyLength, averageBody, idf);
                score += 2.5 * Bm25(document.Heading.GetValueOrDefault(token), document.HeadingLength, averageHeading, idf);
            }
            if (score > 0) matches.Add((document, score));
        }
        return matches.OrderByDescending(x => x.Score)
            .ThenBy(x => x.Document.ChunkId, StringComparer.Ordinal)
            .Take(5)
            .Select(x => new NutritionKnowledgeHitResponse(x.Document.ChunkId, x.Document.Title,
                Excerpt(x.Document.Text, query), x.Document.PdfPage, x.Document.PrintedPage,
                SourceTitle, x.Document.SourceRevisionId))
            .ToArray();
    }

    private IReadOnlyList<Document> Load()
    {
        if (string.IsNullOrWhiteSpace(_options.CorpusPath) || !File.Exists(_options.CorpusPath))
            throw new InvalidOperationException("Nutrition knowledge corpus is unavailable.");
        var bytes = File.ReadAllBytes(_options.CorpusPath);
        var actual = Convert.ToHexString(SHA256.HashData(bytes));
        if (!actual.Equals(_options.CorpusSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Nutrition knowledge corpus digest mismatch.");
        var documents = new List<Document>();
        foreach (var line in File.ReadLines(_options.CorpusPath))
        {
            using var json = JsonDocument.Parse(line);
            var root = json.RootElement;
            if (!root.GetProperty("index_eligible").GetBoolean() ||
                root.GetProperty("source_id").GetString() != SourceId) continue;
            var headings = root.GetProperty("headings").EnumerateArray()
                .Select(x => x.GetString() ?? "").ToArray();
            var body = root.GetProperty("text").GetString() ?? "";
            var heading = string.Join(" ", headings);
            var bodyTokens = Tokens(body).ToArray();
            var headingTokens = Tokens(heading).ToArray();
            documents.Add(new Document(root.GetProperty("chunk_id").GetString() ?? "",
                root.GetProperty("source_revision_id").GetString() ?? "", body,
                headings.LastOrDefault(x => !string.IsNullOrWhiteSpace(x)) ?? "Tài liệu dinh dưỡng",
                root.GetProperty("pdf_page").GetInt32(),
                root.GetProperty("printed_page").ValueKind switch
                {
                    JsonValueKind.Null => null,
                    JsonValueKind.String => root.GetProperty("printed_page").GetString(),
                    JsonValueKind.Number => root.GetProperty("printed_page").GetRawText(),
                    _ => throw new InvalidOperationException("Invalid nutrition printed page.")
                },
                bodyTokens.GroupBy(x => x).ToDictionary(x => x.Key, x => x.Count()),
                headingTokens.GroupBy(x => x).ToDictionary(x => x.Key, x => x.Count()),
                bodyTokens.Length, headingTokens.Length));
        }
        if (documents.Count == 0) throw new InvalidOperationException("Nutrition knowledge corpus is empty.");
        return documents;
    }

    private static double Bm25(int frequency, int length, double averageLength, double idf) =>
        frequency == 0 ? 0 : idf * frequency * 2.2 /
        (frequency + 1.2 * (0.25 + 0.75 * length / averageLength));

    private static IEnumerable<string> Tokens(string value)
    {
        var normalized = value.Replace('đ', 'd').Replace('Đ', 'D').ToLowerInvariant()
            .Normalize(NormalizationForm.FormD);
        var withoutMarks = new string(normalized.Where(c =>
            CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark).ToArray());
        return Regex.Matches(withoutMarks, "[a-z0-9_]+", RegexOptions.CultureInvariant)
            .Select(match => match.Value);
    }

    private static string Excerpt(string text, IReadOnlyCollection<string> query)
    {
        var flat = Regex.Replace(text, "\\s+", " ").Trim();
        if (flat.Length <= 420) return flat;
        var searchable = new StringBuilder(flat.Length);
        var positions = new List<int>(flat.Length);
        for (var index = 0; index < flat.Length; index++)
        {
            var normalized = flat[index].ToString().Replace('đ', 'd').Replace('Đ', 'D')
                .ToLowerInvariant().Normalize(NormalizationForm.FormD);
            foreach (var character in normalized)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark) continue;
                searchable.Append(character);
                positions.Add(index);
            }
        }
        var normalizedText = searchable.ToString();
        var first = query.Select(token => normalizedText.IndexOf(token, StringComparison.Ordinal))
            .Where(index => index >= 0).Select(index => positions[index]).DefaultIfEmpty(0).Min();
        var start = Math.Max(0, first - 70);
        var length = Math.Min(420, flat.Length - start);
        return (start > 0 ? "…" : "") + flat.Substring(start, length).Trim() +
            (start + length < flat.Length ? "…" : "");
    }

    private sealed record Document(string ChunkId, string SourceRevisionId, string Text, string Title,
        int PdfPage, string? PrintedPage, Dictionary<string, int> Body, Dictionary<string, int> Heading,
        int BodyLength, int HeadingLength);
}
