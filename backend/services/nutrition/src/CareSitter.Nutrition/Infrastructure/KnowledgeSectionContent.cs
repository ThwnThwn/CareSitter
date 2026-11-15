using System.Text.RegularExpressions;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed record KnowledgeSectionContent(string Heading, string Text, string ContextHeading)
{
    public static KnowledgeSectionContent[] Split(string text, string[] headings, string fallbackHeading)
    {
        var known = headings.Select(Normalize).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var sections = new List<KnowledgeSectionContent>();
        var body = new List<string>();
        var outline = new List<(int Depth, string Heading)>();
        string? heading = null;
        var context = "";
        foreach (var raw in Regex.Split(text.Trim(), @"\r?\n\s*\r?\n"))
        {
            var paragraph = Normalize(raw);
            if (paragraph.Length == 0) continue;
            var isHeading = known.Contains(paragraph) ||
                paragraph.Length <= 180 && Regex.IsMatch(paragraph,
                    @"^(?:\d+(?:\.\d+)*\.?|[IVX]+\.)\s+\p{Lu}[^.!?]*(?:[.!?])?$");
            if (!isHeading)
            {
                // Diagram glyphs mixed into PDF text cannot support a readable prose summary.
                if (Regex.IsMatch(paragraph, @"\p{Co}")) continue;
                body.Add(paragraph);
                continue;
            }
            // A page can begin with the tail of the previous section. Do not label it as a later heading.
            if (heading is not null) sections.Add(new(heading, string.Join(' ', body), context));
            heading = paragraph;
            var number = Regex.Match(heading, @"^\d+(?:\.\d+)*");
            var depth = number.Success ? 2 + number.Value.Count(character => character == '.') :
                Regex.IsMatch(heading, @"^[IVX]+\.") ? 1 : 0;
            outline.RemoveAll(item => item.Depth >= depth);
            outline.Add((depth, heading));
            context = string.Join(" · ", outline.Select(item => item.Heading));
            body.Clear();
        }
        if (heading is not null) sections.Add(new(heading, string.Join(' ', body), context));
        return sections.Count > 0 ? sections.ToArray() :
            [new(headings.LastOrDefault(value => !string.IsNullOrWhiteSpace(value)) ?? fallbackHeading,
                Normalize(text), string.Join(" · ", headings))];
    }

    public string? Summary()
    {
        // Extract complete sentences from this section only; never create medical claims or cut qualifiers.
        var selected = new List<string>();
        foreach (var raw in Regex.Split(Text, @"(?<=[.!?])\s+"))
        {
            var sentence = Normalize(raw);
            if (sentence.Length is < 35 or > 560 || !Regex.IsMatch(sentence, @"[.!?]$") ||
                !char.IsUpper(sentence[0]) || sentence.Count(char.IsLetter) < sentence.Length / 2 ||
                Regex.IsMatch(sentence, @"^(?:PGS|GS|TS|BS|Hình|Bảng|Nguồn|Tài liệu tham khảo)\b")) continue;
            if (selected.Sum(item => item.Length + 1) + sentence.Length > 560) break;
            selected.Add(sentence);
            if (selected.Count == 2 || sentence.Length >= 180) break;
        }
        return selected.Count == 0 ? null : string.Join(' ', selected);
    }

    private static string Normalize(string text) => Regex.Replace(text.Trim(), @"\s+", " ");
}
