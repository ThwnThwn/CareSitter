using System.Text.Json;
using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

// R3d branch A: the reviewed graph explains keyword citations; it never changes ranking.
// Only metadata (node ID, heading, page) is read. Chunk text is never part of the index.
internal static class MealGraphExplanationIndex
{
    public const string Mode = "reviewed_graph_explanation_index";
    private const int MaximumSteps = 8;
    private const int MaximumPages = 20;

    // Returns null when the index is missing or fails any pin/binding check. Callers then use graphRole=none.
    public static IReadOnlyDictionary<string, MealGraphStep[]>? TryLoad(
        MealGroundingOptions settings, string reviewPolicy, string corpusFreezeSha256)
    {
        if (string.IsNullOrWhiteSpace(settings.ExplanationIndexPath) || string.IsNullOrWhiteSpace(settings.ExplanationIndexSha256) ||
            string.IsNullOrWhiteSpace(settings.ReviewedGraphPath) || string.IsNullOrWhiteSpace(settings.ReviewedGraphSha256))
            return null;
        try
        {
            // The explanation index must come from the pinned reviewed graph, never from a candidate graph.
            using var graph = JsonDocument.Parse(GroundingArtifact.ReadVerified(settings.ReviewedGraphPath, settings.ReviewedGraphSha256));
            RuntimeReleaseArtifact.Verify(graph.RootElement, "reviewed_retrieval_graph");
            if (ReleaseReviewPolicy.Read(graph.RootElement) != reviewPolicy ||
                !RuntimeReleaseArtifact.Equal(graph.RootElement.GetProperty("corpus_freeze_sha256").GetString(), corpusFreezeSha256))
                return null;

            using var index = JsonDocument.Parse(GroundingArtifact.ReadVerified(settings.ExplanationIndexPath, settings.ExplanationIndexSha256));
            var root = index.RootElement;
            RuntimeReleaseArtifact.Verify(root, Mode);
            var bindings = root.GetProperty("bindings");
            if (root.GetProperty("review_policy").GetString() != reviewPolicy ||
                !RuntimeReleaseArtifact.Equal(bindings.GetProperty("graph_sha256").GetString(), graph.RootElement.GetProperty("content_sha256").GetString()) ||
                !RuntimeReleaseArtifact.Equal(bindings.GetProperty("corpus_freeze_sha256").GetString(), corpusFreezeSha256) ||
                !RuntimeReleaseArtifact.Equal(bindings.GetProperty("corpus_sha256").GetString(), settings.CorpusSha256))
                return null;

            var paths = new Dictionary<string, MealGraphStep[]>(StringComparer.Ordinal);
            foreach (var chunk in root.GetProperty("chunks").EnumerateObject())
            {
                var steps = chunk.Value.GetProperty("graphPath").EnumerateArray().Take(MaximumSteps).Select(step => new MealGraphStep(
                    step.GetProperty("node_id").GetString() ?? throw new InvalidOperationException("Graph step is missing a node."),
                    step.TryGetProperty("heading", out var heading) && heading.ValueKind == JsonValueKind.String ? heading.GetString() : null,
                    step.GetProperty("pages").EnumerateArray().Take(MaximumPages).Select(page => page.GetInt32()).ToArray())).ToArray();
                paths[chunk.Name] = steps;
            }
            return paths;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or
            InvalidOperationException or KeyNotFoundException or FormatException or ArgumentException or OverflowException)
        {
            return null;
        }
    }

    public static MealRecommendationEvidence[] Attach(MealRecommendationEvidence[] evidence,
        IReadOnlyDictionary<string, MealGraphStep[]> paths) =>
        evidence.Select(item => paths.TryGetValue(item.Id, out var path) ? item with { GraphPath = path } : item).ToArray();
}
