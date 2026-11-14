using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

public sealed record KnowledgeSearchHit(string ChunkId, string Heading, int PdfPage,
    string? PrintedPage, string SourceTitle, string SourceRevisionId,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? Excerpt = null)
{
    [JsonIgnore] public string? ContextHeading { get; init; }
}

/// <summary>Retrieves only through the authorized grounding release and returns source metadata.</summary>
public sealed class NutritionKnowledgeSearch(IMealKnowledgeRetriever retriever,
    IOptions<MealGroundingOptions> options, IHostEnvironment? environment = null)
{
    internal bool SupportsLocalDemo => environment?.IsDevelopment() == true &&
        options.Value.Mode is MealGroundingOptions.OwnerAuthorizedGraphDemoMode or
            MealGroundingOptions.OwnerAuthorizedCorpusDemoMode;

    public async Task<IReadOnlyList<KnowledgeSearchHit>> FindAsync(string query, CancellationToken ct,
        bool localDemo = false)
    {
        if (!options.Value.Enabled) throw new InvalidOperationException("Knowledge grounding is disabled.");
        var plan = KnowledgeQueryPlan.Create(query);
        var topic = plan.SearchText;
        if (plan.IsEmpty || topic.Length < 2) return [];
        var result = await retriever.RetrieveAsync(new MealKnowledgeRequest([], [], [], "", topic), ct);
        if (!result.Available) throw new InvalidOperationException("Knowledge release is unavailable.");
        // The retriever verifies authorization, review gates and the release's corpus binding.
        var bytes = GroundingArtifact.ReadVerified(options.Value.CorpusPath, options.Value.CorpusSha256);
        // Fuse ranks rather than replacing the authorized graph traversal with lexical results.
        var evidence = SupportsLocalDemo
            ? Fuse(result.Evidence, new KeywordMealKnowledgeIndex(bytes).Search(topic, 100, 0, ct: ct))
            : result.Evidence;
        return MapHits(query, bytes, evidence, options.Value.TopK, localDemo && SupportsLocalDemo);
    }

    internal static IReadOnlyList<KnowledgeSearchHit> MapHits(string query, byte[] bytes,
        MealRecommendationEvidence[] evidence, int topK, bool showExcerpts)
    {
        var plan = KnowledgeQueryPlan.Create(query);
        if (evidence.Length == 0) return [];
        var ids = evidence.Select(x => x.Id).ToHashSet(StringComparer.Ordinal);
        var chunks = new Dictionary<string, (int PdfPage, string? PrintedPage, string Revision, string Text, string Headings)>(StringComparer.Ordinal);
        foreach (var line in Encoding.UTF8.GetString(bytes).Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            using var json = JsonDocument.Parse(line.TrimEnd('\r'));
            var root = json.RootElement;
            var id = root.GetProperty("chunk_id").GetString() ?? "";
            if (!ids.Contains(id)) continue;
            if (!root.GetProperty("index_eligible").GetBoolean() ||
                root.GetProperty("review_status").GetString() != "ready_for_retrieval_eval")
                throw new InvalidOperationException("Released evidence is not eligible.");
            var page = root.TryGetProperty("pdf_page", out var pdf) && pdf.ValueKind == JsonValueKind.Number ? pdf.GetInt32() : 0;
            var printed = root.TryGetProperty("printed_page", out var value) && value.ValueKind != JsonValueKind.Null
                ? value.ToString() : null;
            if (!chunks.TryAdd(id, (page, printed, root.GetProperty("source_revision_id").GetString() ?? "",
                    root.GetProperty("text").GetString() ?? "",
                    root.TryGetProperty("headings", out var headings) && headings.ValueKind == JsonValueKind.Array
                        ? string.Join(" · ", headings.EnumerateArray().Select(heading => heading.GetString())) : "")))
                throw new InvalidOperationException("Released evidence ID is duplicated.");
        }
        return evidence.Select(item =>
        {
            if (!chunks.TryGetValue(item.Id, out var chunk))
                throw new InvalidOperationException("Released evidence is missing from the corpus.");
            var excerpt = RelevantPassage(plan, chunk.Text, chunk.Headings, query);
            if (excerpt is null && !Matches(plan, item.Title, query)) return null;
            return new KnowledgeSearchHit(item.Id, item.Title, chunk.PdfPage, chunk.PrintedPage,
                item.SourceTitle ?? "", chunk.Revision, showExcerpts ? excerpt : null)
                { ContextHeading = chunk.Headings };
        }).OfType<KnowledgeSearchHit>().Where(hit => !showExcerpts || hit.Excerpt is { Length: > 0 })
            .Take(topK).ToArray();
    }

    private static bool Matches(KnowledgeQueryPlan plan, string text, string question)
    {
        // Folding Vietnamese accents must not turn coconut/melon evidence into pineapple evidence.
        var original = question.Normalize().ToLowerInvariant();
        var source = text.Normalize().ToLowerInvariant();
        foreach (var fruit in new[] { "dừa", "dưa" })
            if (Regex.IsMatch(original, $@"\b{fruit}\b") && !Regex.IsMatch(source, $@"\b{fruit}\b")) return false;
        if (IsPineappleQuestion(question) && !Regex.IsMatch(source, @"\b(?:dứa|trái thơm|quả thơm|khóm)\b")) return false;
        return plan.Matches(text);
    }

    internal static bool IsPineappleQuestion(string question) =>
        !Regex.IsMatch(question.Normalize().ToLowerInvariant(), @"\b(?:dừa|dưa)\b") &&
        Regex.IsMatch(KeywordMealKnowledgeIndex.Fold(question), @"\b(?:dua|trai thom|qua thom|khom)\b");

    private static string? RelevantPassage(KnowledgeQueryPlan plan, string text, string headings, string question)
    {
        // PDF line wraps are not sentence boundaries. Keep complete sentences to preserve qualifiers.
        const int maxExcerptLength = 640;
        var continuous = Regex.Replace(text.Trim(), @"\s+", " ");
        var sentences = Regex.Split(continuous, @"(?<=[.!?])\s+");
        if (WeightLossDietScore(question, "thực phẩm") > 0)
        {
            var windows = new List<string>();
            for (var start = 0; start < sentences.Length; start++)
            {
                var window = "";
                for (var offset = 0; offset < 3 && start + offset < sentences.Length; offset++)
                {
                    window = (window + " " + sentences[start + offset]).Trim();
                    if (window.Length > maxExcerptLength) break;
                    if (window.Length >= 18 && plan.MentionsConcept(window) && Matches(plan, headings + " " + window, question))
                        windows.Add(window);
                }
            }
            var relevant = windows.OrderByDescending(window => WeightLossDietScore(question, window))
                .ThenBy(window => window.Length).FirstOrDefault();
            if (relevant is not null && WeightLossDietScore(question, relevant) > 0) return relevant;
        }
        foreach (var sentence in sentences)
        {
            var normalized = Regex.Replace(sentence.Trim(), @"\s+", " ");
            if (normalized.Length is >= 18 and <= maxExcerptLength && Matches(plan, normalized, question))
                return normalized;
        }
        // Conditions may be in the section heading rather than repeated in every sentence.
        // A short adjacent-sentence window preserves the local context without borrowing unrelated pages.
        for (var start = 0; start < sentences.Length; start++)
        {
            var passage = "";
            for (var offset = 0; offset < 3 && start + offset < sentences.Length; offset++)
            {
                passage = (passage + " " + sentences[start + offset]).Trim();
                if (passage.Length > maxExcerptLength) break;
                if (passage.Length >= 18 && plan.MentionsConcept(passage) &&
                    Matches(plan, headings + " " + passage, question)) return passage;
            }
        }
        return null;
    }

    // Query intent affects ranking only, never adds facts or changes the source text.
    internal static int WeightLossDietScore(string query, string text)
    {
        if (!Regex.IsMatch(KeywordMealKnowledgeIndex.Fold(query), @"\b(?:giam can|an kieng)\b")) return 0;
        var folded = KeywordMealKnowledgeIndex.Fold(text);
        var score = new[] { "che do an", "thuc pham", "nang luong", "protein", "chat xo", "rau", "khau phan" }
            .Sum(term => Regex.IsMatch(folded, $@"\b{term}\b") ? 3 : 0);
        if (Regex.IsMatch(folded, @"\b(?:tre em|ung thu|tai lieu tham khao)\b")) score -= 20;
        return score;
    }

    internal static MealRecommendationEvidence[] Fuse(MealRecommendationEvidence[] graph,
        MealRecommendationEvidence[] lexical) => graph.Select((item, rank) => (Item: item, Score: 1d / (60 + rank)))
        .Concat(lexical.Select((item, rank) => (Item: item, Score: 1d / (60 + rank))))
        .GroupBy(item => item.Item.Id, StringComparer.Ordinal)
        .OrderByDescending(group => group.Sum(item => item.Score))
        .ThenBy(group => group.Key, StringComparer.Ordinal)
        .Select(group => group.First().Item).ToArray();
}
