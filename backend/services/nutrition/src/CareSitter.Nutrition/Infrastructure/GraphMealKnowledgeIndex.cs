using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

// Trust decisions belong to the demo/release adapters; traversal uses the same bounded index.
internal sealed class GraphMealKnowledgeIndex
{
    private const int MaximumSeeds = 12;
    private const int MaximumHops = 2;
    private readonly IReadOnlyDictionary<string, GraphNode> _nodes;
    private readonly IReadOnlyDictionary<string, HashSet<string>> _adjacency;
    private readonly IReadOnlyDictionary<string, KnowledgeChunk> _chunks;
    public string? CorpusFreezeSha256 { get; }

    private GraphMealKnowledgeIndex(string? corpusFreezeSha256, Dictionary<string, GraphNode> nodes,
        Dictionary<string, HashSet<string>> adjacency, Dictionary<string, KnowledgeChunk> chunks)
    {
        CorpusFreezeSha256 = corpusFreezeSha256;
        _nodes = nodes;
        _adjacency = adjacency;
        _chunks = chunks;
    }

    public (MealRecommendationEvidence[] Evidence, bool EmptyQuery) Retrieve(
        MealKnowledgeRequest request, int topK, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var tokens = Tokens(string.Join(' ', request.Conditions.Concat(request.Nutrients)
            .Concat(request.Ingredients).Append(request.DietaryPattern).Append(request.NutritionGoal)))
            .Distinct(StringComparer.Ordinal).ToArray();
        if (tokens.Length == 0) return ([], true);
        var seeds = _nodes.Values.Select(node => (Node: node, Score: Score(node.Label, tokens)))
            .Where(item => item.Score > 0).OrderByDescending(item => item.Score)
            .ThenBy(item => item.Node.Id, StringComparer.Ordinal).Take(MaximumSeeds);
        var scores = new Dictionary<string, double>(StringComparer.Ordinal);
        foreach (var seed in seeds)
        {
            ct.ThrowIfCancellationRequested();
            Traverse(seed.Node.Id, seed.Score, scores, ct);
        }
        return (scores.OrderByDescending(item => item.Value).ThenBy(item => item.Key, StringComparer.Ordinal)
            .Select(item => _chunks[item.Key]).Take(topK).Select(chunk => chunk.ToEvidence()).ToArray(), false);
    }

    private void Traverse(string start, double score, IDictionary<string, double> chunks, CancellationToken ct)
    {
        var queue = new Queue<(string Id, int Hop)>();
        var visited = new HashSet<string>(StringComparer.Ordinal) { start };
        queue.Enqueue((start, 0));
        while (queue.Count > 0)
        {
            ct.ThrowIfCancellationRequested();
            var (id, hop) = queue.Dequeue();
            if (_nodes[id].ChunkId is { Length: > 0 } chunkId)
            {
                chunks.TryGetValue(chunkId, out var current);
                chunks[chunkId] = Math.Max(current, score + 2 - hop * 0.5);
            }
            if (hop == MaximumHops || !_adjacency.TryGetValue(id, out var adjacent)) continue;
            foreach (var next in adjacent.Order(StringComparer.Ordinal))
                if (visited.Add(next)) queue.Enqueue((next, hop + 1));
        }
    }

    public static GraphMealKnowledgeIndex Load(byte[] graphBytes, byte[] corpusBytes, string requiredMode)
    {
        using var graphJson = JsonDocument.Parse(graphBytes);
        var root = graphJson.RootElement;
        if (root.GetProperty("mode").GetString() != requiredMode ||
            root.GetProperty("nodes").GetArrayLength() == 0 || root.GetProperty("edges").GetArrayLength() == 0)
            throw new InvalidOperationException("Grounding graph is empty or has an unexpected mode.");
        var nodes = new Dictionary<string, GraphNode>(StringComparer.Ordinal);
        foreach (var node in root.GetProperty("nodes").EnumerateArray())
        {
            var id = node.GetProperty("id").GetString() ?? "";
            var value = new GraphNode(id, node.GetProperty("label").GetString() ?? "",
                node.TryGetProperty("chunk_id", out var chunk) ? chunk.GetString() : null);
            if (id.Length == 0 || !nodes.TryAdd(id, value))
                throw new InvalidOperationException("Grounding graph node IDs must be nonempty and unique.");
        }
        var adjacency = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        foreach (var edge in root.GetProperty("edges").EnumerateArray())
        {
            var from = edge.GetProperty("from").GetString() ?? "";
            var to = edge.GetProperty("to").GetString() ?? "";
            if (!nodes.ContainsKey(from) || !nodes.ContainsKey(to))
                throw new InvalidOperationException("Grounding graph contains a dangling edge.");
            Add(adjacency, from, to); Add(adjacency, to, from);
        }
        var chunks = LoadChunks(corpusBytes);
        if (!nodes.Values.Any(node => node.ChunkId is { Length: > 0 }) ||
            nodes.Values.Where(node => node.ChunkId is not null).Any(node => !chunks.ContainsKey(node.ChunkId!)))
            throw new InvalidOperationException("Grounding graph references an ineligible corpus chunk.");
        return new(root.TryGetProperty("corpus_freeze_sha256", out var freeze) ? freeze.GetString() : null,
            nodes, adjacency, chunks);
    }

    private static Dictionary<string, KnowledgeChunk> LoadChunks(byte[] corpusBytes)
    {
        var chunks = new Dictionary<string, KnowledgeChunk>(StringComparer.Ordinal);
        foreach (var line in Encoding.UTF8.GetString(corpusBytes).Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            using var item = JsonDocument.Parse(line.TrimEnd('\r'));
            var chunk = item.RootElement;
            if (!chunk.GetProperty("index_eligible").GetBoolean() ||
                chunk.GetProperty("review_status").GetString() != "ready_for_retrieval_eval") continue;
            var id = chunk.GetProperty("chunk_id").GetString() ?? "";
            var headings = chunk.GetProperty("headings").EnumerateArray().Select(value => value.GetString() ?? "").ToArray();
            var text = chunk.GetProperty("text").GetString()?.Trim() ?? "";
            var value = new KnowledgeChunk(id, headings.LastOrDefault(value => value.Length > 0) ?? "Tài liệu dinh dưỡng",
                headings.FirstOrDefault(value => value.Length > 0),
                chunk.TryGetProperty("printed_page", out var printed) && printed.ValueKind != JsonValueKind.Null
                    ? printed.ToString() : null,
                chunk.GetProperty("source_locator").GetString() ?? "",
                chunk.TryGetProperty("pdf_page", out var pdf) ? pdf.GetInt32() : null,
                text[..Math.Min(text.Length, 1600)], ResolveSourceTitle(chunk));
            if (id.Length == 0 || !chunks.TryAdd(id, value))
                throw new InvalidOperationException("Grounding corpus chunk IDs must be nonempty and unique.");
        }
        return chunks;
    }

    private static void Add(IDictionary<string, HashSet<string>> graph, string from, string to)
    {
        if (!graph.TryGetValue(from, out var values)) graph[from] = values = new(StringComparer.Ordinal);
        values.Add(to);
    }

    private static int Score(string value, IReadOnlyCollection<string> tokens)
    {
        var haystack = string.Join(' ', Tokens(value));
        return tokens.Count(token => haystack.Contains(token, StringComparison.Ordinal));
    }

    private static IEnumerable<string> Tokens(string value)
    {
        var normalized = value.Replace('đ', 'd').Replace('Đ', 'D').ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var plain = new string(normalized.Where(character =>
            CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark).ToArray());
        return Regex.Matches(plain, "[a-z0-9_]+", RegexOptions.CultureInvariant).Select(match => match.Value);
    }

    private static string ResolveSourceTitle(JsonElement chunk) =>
        (chunk.TryGetProperty("source_id", out var source) ? source.GetString() : null) switch
        {
            "vdd-ten-nutrition-recommendations-2030-en" => "Ten Recommendations for Proper Nutrition toward 2030 — Ministry of Health",
            "who-fao-healthy-diets-2024" => "What are healthy diets? — WHO/FAO, 2024",
            "who-europe-healthy-ageing-diets-2023" => "Promoting physical activity and healthy diets for healthy ageing — WHO Europe, 2023",
            _ => "Dinh dưỡng lâm sàng — Viện Dinh dưỡng, 2019"
        };

    private sealed record GraphNode(string Id, string Label, string? ChunkId);
    private sealed record KnowledgeChunk(string Id, string Title, string? Chapter, string? PrintedPage,
        string Locator, int? PdfPage, string Excerpt, string SourceTitle)
    {
        public MealRecommendationEvidence ToEvidence() => new(Id, Title, Chapter, PrintedPage, Locator,
            $"{SourceTitle}, {(PrintedPage is { Length: > 0 } ? $"trang {PrintedPage}" : PdfPage is > 0 ? $"PDF trang {PdfPage}" : Locator)}", Excerpt);
    }
}
