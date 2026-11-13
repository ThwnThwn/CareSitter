using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Nutrition.Infrastructure;

try
{
    if (args.Length != 1) return 1;
    var index = new KeywordMealKnowledgeIndex(File.ReadAllBytes(args[0]));
    using var cases = JsonDocument.Parse(Console.In.ReadToEnd());
    var rows = cases.RootElement.EnumerateArray().Select(item =>
    {
        var question = item.GetProperty("question").GetString()!;
        var revision = item.TryGetProperty("source_revision_id", out var source) ? source.GetString() : null;
        var guard = item.TryGetProperty("edition_guard", out var edition) && edition.GetBoolean();
        var filter = item.TryGetProperty("filter_revision", out var filtered) && filtered.GetBoolean();
        var evidence = index.Search(question,
            item.TryGetProperty("top_k", out var topK) ? topK.GetInt32() : 5,
            item.TryGetProperty("minimum_score", out var minimum) ? minimum.GetDouble() : 0,
            filter || guard ? revision : null, guard);
        return new { case_id = item.GetProperty("case_id").GetString(),
            question_sha256 = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(question))).ToLowerInvariant(),
            chunk_ids = evidence.Select(e => e.Id).ToArray() };
    }).ToArray();
    Console.WriteLine(JsonSerializer.Serialize(rows));
    return 0;
}
catch
{
    // Do not log local corpus/parser exceptions: this command is safe for book parity.
    return 1;
}
