using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class OwnerAuthorizedCorpusMealKnowledgeRetriever : IMealKnowledgeRetriever
{
    private const string SourceId = "book-dinh-duong-lam-sang-2019";
    private readonly MealGroundingOptions _options;
    private readonly IHostEnvironment _environment;
    private readonly Lazy<DemoCorpus> _corpus;

    public OwnerAuthorizedCorpusMealKnowledgeRetriever(IOptions<MealGroundingOptions> options,
        IHostEnvironment environment)
    {
        _options = options.Value;
        _environment = environment;
        _corpus = new Lazy<DemoCorpus>(Load);
    }

    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        try
        {
            var corpus = _corpus.Value;
            var query = Tokens(string.Join(' ', request.Conditions.Concat(request.Nutrients)
                .Concat(request.Ingredients).Append(request.DietaryPattern).Append(request.NutritionGoal)))
                .Distinct(StringComparer.Ordinal).ToArray();
            if (query.Length == 0)
                return Task.FromResult(new MealKnowledgeResult(true, corpus.Revision,
                    MealGroundingOptions.OwnerAuthorizedCorpusDemoMode, [], ["grounding_query_empty"]));
            var count = corpus.Documents.Length;
            var averageBody = corpus.Documents.Average(item => item.BodyLength);
            var averageHeading = Math.Max(1, corpus.Documents.Average(item => item.HeadingLength));
            var evidence = corpus.Documents.Select(document =>
                (Document: document, Score: Score(document, query, corpus.Documents, count,
                    averageBody, averageHeading)))
                .Where(item => item.Score > 0)
                .OrderByDescending(item => item.Score)
                .ThenBy(item => item.Document.Id, StringComparer.Ordinal)
                .Take(_options.TopK)
                .Select(item => item.Document.ToEvidence()).ToArray();
            return Task.FromResult(new MealKnowledgeResult(true, corpus.Revision,
                MealGroundingOptions.OwnerAuthorizedCorpusDemoMode, evidence,
                ["academic_demo_owner_authorized", "independent_clinical_review_not_claimed"]));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or
            JsonException or InvalidOperationException)
        {
            return Task.FromResult(MealKnowledgeResult.Unavailable("grounding_demo_authorization_invalid"));
        }
    }

    private DemoCorpus Load()
    {
        if (!_environment.IsDevelopment())
            throw new InvalidOperationException("Owner-authorized corpus demo is Development-only.");
        var authorizationBytes = ReadVerified(_options.DemoAuthorizationPath,
            _options.DemoAuthorizationSha256);
        using var authorization = JsonDocument.Parse(authorizationBytes);
        var root = authorization.RootElement;
        if (root.GetProperty("mode").GetString() != "owner_authorized_academic_demo" ||
            root.GetProperty("authorized_environment").GetString() != "Development" ||
            root.GetProperty("authorized_use").GetString() != "academic_demo" ||
            !root.GetProperty("owner_accepted").GetBoolean() ||
            root.GetProperty("reviewer_type").GetString() != "ai_assisted" ||
            root.GetProperty("accepted_cases").GetInt32() != 54 ||
            root.GetProperty("total_cases").GetInt32() != 54 ||
            root.GetProperty("independent_clinical_review").GetBoolean())
            throw new InvalidOperationException("Academic demo authorization is incomplete.");
        var authorizedCorpusHash = root.GetProperty("corpus_sha256").GetString();
        if (!string.Equals(authorizedCorpusHash, _options.CorpusSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Academic demo authorization targets another corpus.");

        var corpusBytes = ReadVerified(_options.CorpusPath, _options.CorpusSha256);
        var documents = new List<Document>();
        foreach (var line in Encoding.UTF8.GetString(corpusBytes)
                     .Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            using var item = JsonDocument.Parse(line.TrimEnd('\r'));
            var chunk = item.RootElement;
            if (!chunk.GetProperty("index_eligible").GetBoolean() ||
                chunk.GetProperty("source_id").GetString() != SourceId ||
                chunk.GetProperty("review_status").GetString() != "ready_for_retrieval_eval") continue;
            var headings = chunk.GetProperty("headings").EnumerateArray()
                .Select(value => value.GetString() ?? "").ToArray();
            var text = chunk.GetProperty("text").GetString() ?? "";
            var bodyTokens = Tokens(text).ToArray();
            var headingTokens = Tokens(string.Join(' ', headings)).ToArray();
            documents.Add(new Document(chunk.GetProperty("chunk_id").GetString() ?? "",
                headings.LastOrDefault(value => value.Length > 0) ?? "Tài liệu dinh dưỡng",
                headings.FirstOrDefault(value => value.Length > 0),
                PrintedPage(chunk), chunk.GetProperty("source_locator").GetString() ?? "",
                chunk.GetProperty("pdf_page").GetInt32(), LimitExcerpt(text),
                bodyTokens.GroupBy(value => value).ToDictionary(group => group.Key, group => group.Count()),
                headingTokens.GroupBy(value => value).ToDictionary(group => group.Key, group => group.Count()),
                bodyTokens.Length, headingTokens.Length));
        }
        if (documents.Count == 0)
            throw new InvalidOperationException("Academic demo corpus is empty.");
        return new DemoCorpus(root.GetProperty("case_set_sha256").GetString() ??
            _options.CorpusSha256, documents.ToArray());
    }

    private static double Score(Document document, IReadOnlyCollection<string> query,
        IReadOnlyCollection<Document> documents, int count, double averageBody, double averageHeading)
    {
        double score = 0;
        foreach (var token in query)
        {
            var frequency = documents.Count(item => item.Body.ContainsKey(token) || item.Heading.ContainsKey(token));
            if (frequency == 0) continue;
            var idf = Math.Log(1 + (count - frequency + 0.5) / (frequency + 0.5));
            score += Bm25(document.Body.GetValueOrDefault(token), document.BodyLength, averageBody, idf);
            score += 2.5 * Bm25(document.Heading.GetValueOrDefault(token), document.HeadingLength,
                averageHeading, idf);
        }
        return score;
    }

    private static double Bm25(int frequency, int length, double averageLength, double idf) =>
        frequency == 0 ? 0 : idf * frequency * 2.2 /
        (frequency + 1.2 * (0.25 + 0.75 * length / averageLength));

    private static IEnumerable<string> Tokens(string value)
    {
        var normalized = value.Replace('đ', 'd').Replace('Đ', 'D').ToLowerInvariant()
            .Normalize(NormalizationForm.FormD);
        var plain = new string(normalized.Where(character =>
            CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark).ToArray());
        return Regex.Matches(plain, "[a-z0-9_]+", RegexOptions.CultureInvariant)
            .Select(match => match.Value);
    }

    private static byte[] ReadVerified(string path, string expected)
    {
        if (!Path.IsPathFullyQualified(path) || !File.Exists(path))
            throw new InvalidOperationException("Academic demo grounding artifact is unavailable.");
        var bytes = File.ReadAllBytes(path);
        if (!Convert.ToHexString(SHA256.HashData(bytes)).Equals(expected,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Academic demo grounding artifact digest mismatch.");
        return bytes;
    }

    private static string? PrintedPage(JsonElement chunk) =>
        chunk.TryGetProperty("printed_page", out var value) && value.ValueKind != JsonValueKind.Null
            ? value.ToString()
            : null;

    private static string LimitExcerpt(string value)
    {
        var trimmed = value.Trim();
        return trimmed[..Math.Min(trimmed.Length, 1600)];
    }

    private sealed record Document(string Id, string Title, string? Chapter, string? PrintedPage,
        string Locator, int PdfPage, string Excerpt, Dictionary<string, int> Body,
        Dictionary<string, int> Heading, int BodyLength, int HeadingLength)
    {
        public MealRecommendationEvidence ToEvidence() => new(Id, Title, Chapter, PrintedPage, Locator,
            $"Dinh dưỡng lâm sàng — Viện Dinh dưỡng, 2019, " +
            (PrintedPage is { Length: > 0 } ? $"trang {PrintedPage}" : $"PDF trang {PdfPage}"), Excerpt);
    }

    private sealed record DemoCorpus(string Revision, Document[] Documents);
}
