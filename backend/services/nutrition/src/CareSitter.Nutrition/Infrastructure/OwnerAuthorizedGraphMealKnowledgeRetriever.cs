using System.Text.Json;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class OwnerAuthorizedGraphMealKnowledgeRetriever : IMealKnowledgeRetriever
{
    private static readonly string[] DemoWarnings =
        ["academic_demo_owner_authorized", "graph_candidate_not_independently_reviewed", "independent_clinical_review_not_claimed"];
    private readonly MealGroundingOptions _options;
    private readonly IHostEnvironment _environment;
    private readonly LocalDemoCatalogOptions _catalog;
    private readonly Lazy<GraphMealKnowledgeIndex> _graph;

    public OwnerAuthorizedGraphMealKnowledgeRetriever(IOptions<MealGroundingOptions> options,
        IHostEnvironment environment, LocalDemoCatalogOptions catalog)
    {
        _options = options.Value;
        _environment = environment;
        _catalog = catalog;
        _graph = new(Load);
    }

    public Task<MealKnowledgeResult> RetrieveAsync(MealKnowledgeRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        try
        {
            var graph = _graph.Value;
            var match = graph.Retrieve(request, _options.TopK, ct);
            var warnings = match.EmptyQuery ? DemoWarnings.Append("grounding_query_empty").ToArray() :
                match.Evidence.Length == 0 ? DemoWarnings.Append("grounding_insufficient_evidence").ToArray() : DemoWarnings;
            return Task.FromResult(new MealKnowledgeResult(true, graph.CorpusFreezeSha256,
                MealGroundingOptions.OwnerAuthorizedGraphDemoMode, match.Evidence, warnings));
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or
            InvalidOperationException or KeyNotFoundException or FormatException)
        {
            return Task.FromResult(new MealKnowledgeResult(false, null, MealGroundingOptions.OwnerAuthorizedGraphDemoMode,
                [], [.. DemoWarnings, "grounding_graph_demo_authorization_invalid"]));
        }
    }

    private GraphMealKnowledgeIndex Load()
    {
        if (!_environment.IsDevelopment() || !_catalog.Enabled)
            throw new InvalidOperationException("Graph demo requires the Development local-demo catalog.");
        using var authorization = JsonDocument.Parse(GroundingArtifact.ReadVerified(
            _options.DemoAuthorizationPath, _options.DemoAuthorizationSha256));
        var root = authorization.RootElement;
        if (root.GetProperty("schema_version").GetInt32() != 1 ||
            root.GetProperty("mode").GetString() != MealGroundingOptions.OwnerAuthorizedGraphDemoMode ||
            root.GetProperty("authorized_environment").GetString() != "Development" ||
            root.GetProperty("authorized_use").GetString() != "academic_demo" ||
            !root.GetProperty("owner_accepted").GetBoolean() ||
            string.IsNullOrWhiteSpace(root.GetProperty("authorization_id").GetString()) ||
            root.GetProperty("graph_review_status").GetString() != "candidate_not_independently_reviewed" ||
            root.GetProperty("independent_clinical_review").GetBoolean() ||
            root.GetProperty("production_release_authorized").GetBoolean())
            throw new InvalidOperationException("Graph demo authorization is incomplete.");
        if (!string.Equals(root.GetProperty("graph_sha256").GetString(), _options.DemoGraphSha256,
                StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(root.GetProperty("corpus_sha256").GetString(), _options.CorpusSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Graph demo authorization targets different artifacts.");
        var graph = GraphMealKnowledgeIndex.Load(
            GroundingArtifact.ReadVerified(_options.DemoGraphPath, _options.DemoGraphSha256),
            GroundingArtifact.ReadVerified(_options.CorpusPath, _options.CorpusSha256), "retrieval_graph_candidate");
        if (string.IsNullOrWhiteSpace(graph.CorpusFreezeSha256) ||
            !string.Equals(root.GetProperty("corpus_freeze_sha256").GetString(), graph.CorpusFreezeSha256,
                StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Graph demo corpus freeze binding is invalid.");
        return graph;
    }
}
