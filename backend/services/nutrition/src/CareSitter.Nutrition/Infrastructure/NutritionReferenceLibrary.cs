using System.Security.Cryptography;
using System.Text.RegularExpressions;
using CareSitter.Nutrition.Application;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Nutrition.Infrastructure;

public sealed record NutritionReferenceOptions
{
    public bool Enabled { get; init; }
    public string ReleaseKey { get; init; } = "";
}

public interface INutritionReferenceLibrary
{
    Task<IReadOnlyList<KnowledgeSearchHit>?> FindAsync(string query, CancellationToken ct);
}

/// <summary>Reads only explicitly authorized reference releases; never used to select clinical meal rules.</summary>
internal sealed class NutritionReferenceLibrary(NpgsqlDataSource database,
    IOptions<NutritionReferenceOptions> options) : INutritionReferenceLibrary
{
    private sealed record Cache(string CorpusHash, string GraphHash, ReferenceKnowledgeIndex Index);
    private Cache? _cache;
    private readonly SemaphoreSlim _load = new(1, 1);

    public async Task<IReadOnlyList<KnowledgeSearchHit>?> FindAsync(string query, CancellationToken ct)
    {
        var settings = options.Value;
        if (!settings.Enabled) return null;
        if (!Regex.IsMatch(settings.ReleaseKey, "^[a-z0-9][a-z0-9-]{2,119}$"))
            throw new InvalidOperationException("Reference release is not configured.");
        await using var connection = await database.OpenConnectionAsync(ct);
        // Check authorization on every request even when indexes are cached: revocation is immediate.
        const string predicate = "release_key=@key AND enabled AND rights_confirmed AND intended_use='nutrition_reference' AND NOT independent_clinical_review";
        await using var metadata = new NpgsqlCommand("SELECT corpus_sha256,graph_sha256 FROM nutrition.reference_knowledge_releases WHERE " + predicate, connection);
        metadata.Parameters.AddWithValue("key", settings.ReleaseKey);
        string corpusHash, graphHash;
        await using (var reader = await metadata.ExecuteReaderAsync(ct))
        {
            if (!await reader.ReadAsync(ct)) throw new InvalidOperationException("Reference release is unavailable.");
            corpusHash = reader.GetString(0); graphHash = reader.GetString(1);
        }
        await _load.WaitAsync(ct);
        try
        {
            if (_cache is null || _cache.CorpusHash != corpusHash || _cache.GraphHash != graphHash)
            {
                await using var payload = new NpgsqlCommand("SELECT corpus,graph FROM nutrition.reference_knowledge_releases WHERE " +
                    predicate + " AND corpus_sha256=@corpus AND graph_sha256=@graph", connection);
                payload.Parameters.AddWithValue("key", settings.ReleaseKey);
                payload.Parameters.AddWithValue("corpus", corpusHash); payload.Parameters.AddWithValue("graph", graphHash);
                await using var reader = await payload.ExecuteReaderAsync(ct);
                if (!await reader.ReadAsync(ct)) throw new InvalidOperationException("Reference release changed.");
                var corpus = reader.GetFieldValue<byte[]>(0); var graph = reader.GetFieldValue<byte[]>(1);
                if (corpus.Length > 10485760 || graph.Length > 10485760 ||
                    Convert.ToHexString(SHA256.HashData(corpus)).ToLowerInvariant() != corpusHash ||
                    Convert.ToHexString(SHA256.HashData(graph)).ToLowerInvariant() != graphHash)
                    throw new InvalidOperationException("Reference release content hash mismatch.");
                _cache = new(corpusHash, graphHash, new ReferenceKnowledgeIndex(corpus, graph));
            }
            return _cache.Index.Find(query, ct);
        }
        finally { _load.Release(); }
    }
}

internal sealed class ReferenceKnowledgeIndex
{
    private readonly byte[] _corpus;
    private readonly GraphMealKnowledgeIndex _graph;
    private readonly KeywordMealKnowledgeIndex _lexical;
    public ReferenceKnowledgeIndex(byte[] corpus, byte[] graph)
    {
        _corpus = corpus;
        // Keep the graph's actual candidate status; owner permission does not manufacture review evidence.
        _graph = GraphMealKnowledgeIndex.Load(graph, corpus, "retrieval_graph_candidate");
        _lexical = new(corpus);
    }
    public IReadOnlyList<KnowledgeSearchHit> Find(string query, CancellationToken ct)
    {
        var plan = KnowledgeQueryPlan.Create(query);
        if (plan.IsEmpty) return [];
        var graph = _graph.Retrieve(new MealKnowledgeRequest([], [], [], "", plan.SearchText), 30, ct).Evidence;
        var evidence = NutritionKnowledgeSearch.Fuse(graph, _lexical.Search(plan.SearchText, 100, 0, ct: ct));
        return NutritionKnowledgeSearch.MapHits(query, _corpus, evidence, 100, true)
            .OrderByDescending(hit => NutritionKnowledgeSearch.WeightLossDietScore(query,
                hit.Heading + " " + hit.ContextHeading + " " + hit.Excerpt))
            .Take(5).ToArray();
    }
}
