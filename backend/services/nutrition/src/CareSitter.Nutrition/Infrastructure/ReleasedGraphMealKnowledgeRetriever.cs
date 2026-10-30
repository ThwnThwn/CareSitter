using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class ReleasedGraphMealKnowledgeRetriever : IMealKnowledgeRetriever
{
    private readonly MealGroundingOptions _options;
    private readonly Lazy<(string Revision, GraphMealKnowledgeIndex Index)> _released;

    public ReleasedGraphMealKnowledgeRetriever(IOptions<MealGroundingOptions> options)
    {
        _options = options.Value;
        _released = new(Load);
    }

    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        try
        {
            var released = _released.Value;
            var match = released.Index.Retrieve(request, _options.TopK, ct);
            return Task.FromResult(new MealKnowledgeResult(true, released.Revision, "graph", match.Evidence,
                match.EmptyQuery ? ["grounding_query_empty"] :
                match.Evidence.Length == 0 ? ["grounding_insufficient_evidence"] : []));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or
            InvalidOperationException or KeyNotFoundException or FormatException)
        {
            return Task.FromResult(MealKnowledgeResult.Unavailable("grounding_release_invalid"));
        }
    }

    private (string Revision, GraphMealKnowledgeIndex Index) Load()
    {
        var manifestBytes = GroundingArtifact.ReadVerified(_options.ManifestPath, _options.ManifestSha256);
        using var manifest = JsonDocument.Parse(manifestBytes);
        var root = manifest.RootElement;
        if (root.GetProperty("release_ready").GetBoolean() is false ||
            root.GetProperty("runtime_integration_authorized").GetBoolean() is false ||
            root.GetProperty("decision").GetString() != "simplest_strategy_passing_all_gates" ||
            root.GetProperty("selected_strategy").GetString() != "graph" ||
            root.GetProperty("gate_failures").GetArrayLength() != 0)
            throw new InvalidOperationException("Graph release is not authorized for runtime integration.");
        var revision = root.GetProperty("bindings").GetProperty("corpus_freeze_sha256").GetString();
        var graphBinding = root.GetProperty("bindings").GetProperty("graph_sha256").GetString();
        if (string.IsNullOrWhiteSpace(revision) || string.IsNullOrWhiteSpace(graphBinding))
            throw new InvalidOperationException("Graph release bindings are incomplete.");

        var graphBytes = GroundingArtifact.ReadVerified(_options.ReviewedGraphPath, _options.ReviewedGraphSha256);
        if (!graphBinding.Equals(_options.ReviewedGraphSha256, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Reviewed graph does not match its release binding.");
        var corpusBytes = GroundingArtifact.ReadVerified(_options.CorpusPath, _options.CorpusSha256);
        return (revision, GraphMealKnowledgeIndex.Load(graphBytes, corpusBytes, "reviewed_retrieval_graph"));
    }
}
