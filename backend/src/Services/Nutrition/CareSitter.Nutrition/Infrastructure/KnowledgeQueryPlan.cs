using System.Text.RegularExpressions;

namespace CareSitter.Nutrition.Infrastructure;

/// <summary>Search vocabulary only; aliases never introduce health claims or expand one disease into another.</summary>
internal sealed class KnowledgeQueryPlan(string[][] concepts)
{
    private static readonly string[][] Aliases =
    [
        ["tang huyet ap", "cao huyet ap", "huyet ap cao"],
        ["dai thao duong", "tieu duong"],
        ["trai cay", "hoa qua", "qua chin", "rau qua", "rau va qua", "rau cu qua"],
        ["protein", "chat dam", "protid"],
        ["chat xo", "xo thuc pham"],
        ["beo phi", "giam can", "thua can", "kiem soat can nang"],
        ["thuc pham", "mon an"],
        ["dua", "trai thom", "qua thom", "khom"]
    ];
    private static readonly HashSet<string> QuestionWords = new(
        "va cua trong cho ve co o tot nguoi benh nen an uong nao gi nhung cac loai phu hop voi duoc khong la the nhu the nao tac dung loi ich cong dung vai tro toi muon biet tim hieu suc khoe khau phan hay giup de cach sach tai lieu nhac den cap liet ke".Split(' '),
        StringComparer.Ordinal);

    public string SearchText => string.Join(' ', concepts.Select(concept => concept[0]));
    public bool IsEmpty => concepts.Length == 0;
    public bool MentionsConcept(string text)
    {
        var folded = Regex.Replace(KeywordMealKnowledgeIndex.Fold(text), @"\s+", " ");
        return concepts.Any(concept => concept.Any(alias => Regex.IsMatch(folded, $@"\b{Regex.Escape(alias)}\b")));
    }
    public bool Matches(string text)
    {
        var folded = Regex.Replace(KeywordMealKnowledgeIndex.Fold(text), @"\s+", " ");
        return concepts.Length > 0 && concepts.All(concept => concept.Any(alias =>
            Regex.IsMatch(folded, $@"\b{Regex.Escape(alias)}\b")));
    }

    public static KnowledgeQueryPlan Create(string query)
    {
        var remaining = Regex.Replace(KeywordMealKnowledgeIndex.Fold(query), @"\s+", " ");
        remaining = Regex.Replace(remaining, @"\b(?:dinh duong lam sang|dinh duong lam san)\b", " ");
        var concepts = new List<string[]>();
        foreach (var aliases in Aliases)
        {
            var pattern = $@"\b(?:{string.Join('|', aliases.OrderByDescending(alias => alias.Length).Select(Regex.Escape))})\b";
            if (!Regex.IsMatch(remaining, pattern)) continue;
            concepts.Add(aliases);
            remaining = Regex.Replace(remaining, pattern, " ");
        }
        concepts.AddRange(KeywordMealKnowledgeIndex.Tokens(remaining).Where(term => !QuestionWords.Contains(term))
            .Distinct(StringComparer.Ordinal).Select(term => new[] { term }));
        return new(concepts.ToArray());
    }
}
