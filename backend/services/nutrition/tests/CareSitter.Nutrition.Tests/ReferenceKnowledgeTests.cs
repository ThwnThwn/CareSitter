using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Infrastructure;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed class ReferenceKnowledgeTests
{
    internal static byte[] Corpus => Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new
    {
        chunk_id = "reference-1", source_id = "book-dinh-duong-lam-sang-2019", source_revision_id = "synthetic-r1",
        index_eligible = true, review_status = "ready_for_retrieval_eval", source_locator = "pdf-page:42",
        pdf_page = 42, printed_page = "41", headings = new[] { "1. Béo phì" },
        text = "Đây là đoạn thử nghiệm về khẩu phần của người béo phì."
    }) + "\n");
    internal static byte[] Graph => Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new
    {
        mode = "retrieval_graph_candidate", corpus_freeze_sha256 = new string('a',64),
        nodes = new object[] { new { id = "topic", label = "Béo phì" },
            new { id = "passage", label = "Khẩu phần", chunk_id = "reference-1" } },
        edges = new[] { new { from = "topic", to = "passage" } }
    }));

    [Fact]
    public void Reference_retrieval_keeps_exact_excerpt_and_book_page_and_does_not_match_unrelated_query()
    {
        var index = new ReferenceKnowledgeIndex(Corpus, Graph);
        var hit = Assert.Single(index.Find("ăn giảm cân", default));
        Assert.Equal("reference-1", hit.ChunkId);
        Assert.Equal(42, hit.PdfPage); Assert.Equal("41", hit.PrintedPage);
        Assert.Contains("Đây là đoạn thử nghiệm", hit.Excerpt);
        Assert.Contains("2019", hit.SourceTitle);
        Assert.Empty(index.Find("dị ứng đậu phộng", default));
    }
}

public sealed partial class PostgresWorkflowTests
{
    [PostgresFact]
    public async Task Reference_library_is_read_only_hash_bound_and_rechecks_revocation_after_caching()
    {
        var corpus = ReferenceKnowledgeTests.Corpus; var graph = ReferenceKnowledgeTests.Graph;
        await using var db = new NpgsqlConnection(_database); await db.OpenAsync();
        await using var insert = new NpgsqlCommand("""
            INSERT INTO nutrition.reference_knowledge_releases(release_key,corpus,graph,corpus_sha256,graph_sha256,
              rights_confirmed,authorized_by,authorization_reference,intended_use,enabled)
            VALUES('synthetic-reference',@corpus,@graph,@corpusHash,@graphHash,true,'synthetic-owner',
              'Synthetic authorization for test data only','nutrition_reference',true)
            """, db);
        insert.Parameters.AddWithValue("corpus", corpus); insert.Parameters.AddWithValue("graph", graph);
        insert.Parameters.AddWithValue("corpusHash", Convert.ToHexString(SHA256.HashData(corpus)).ToLowerInvariant());
        insert.Parameters.AddWithValue("graphHash", Convert.ToHexString(SHA256.HashData(graph)).ToLowerInvariant());
        await insert.ExecuteNonQueryAsync();
        var library = new NutritionReferenceLibrary(_dataSource, Options.Create(new NutritionReferenceOptions
            { Enabled = true, ReleaseKey = "synthetic-reference" }));
        Assert.Single((await library.FindAsync("ăn giảm cân", default))!);
        await using (var runtime = await _dataSource.OpenConnectionAsync())
        await using (var write = new NpgsqlCommand("UPDATE nutrition.reference_knowledge_releases SET enabled=false", runtime))
            Assert.Equal("42501", (await Assert.ThrowsAsync<PostgresException>(() => write.ExecuteNonQueryAsync())).SqlState);
        await using (var tamper = new NpgsqlCommand("UPDATE nutrition.reference_knowledge_releases SET corpus='changed'::bytea", db))
            Assert.Equal("23514", (await Assert.ThrowsAsync<PostgresException>(() => tamper.ExecuteNonQueryAsync())).SqlState);
        await using (var revoke = new NpgsqlCommand("UPDATE nutrition.reference_knowledge_releases SET enabled=false", db))
            await revoke.ExecuteNonQueryAsync();
        await Assert.ThrowsAsync<InvalidOperationException>(() => library.FindAsync("ăn giảm cân", default));
    }
}
