using System.Text.RegularExpressions;

namespace CareSitter.Nutrition.Infrastructure;

internal static partial class HealthTextRedactor
{
    public static IReadOnlyDictionary<string, string> Redact(IReadOnlyDictionary<string, string> sources)
    {
        var result = new Dictionary<string, string>(sources.Count, StringComparer.Ordinal);
        foreach (var pair in sources) result[pair.Key] = Redact(pair.Value);
        return result;
    }

    internal static string Redact(string value)
    {
        var mask = new bool[value.Length];
        Mark(Email(), value, mask); Mark(Phone(), value, mask); Mark(LongNumber(), value, mask);
        Mark(Uuid(), value, mask); Mark(Url(), value, mask); Mark(Jwt(), value, mask);
        MarkGroup(ExplicitName(), "value", value, mask);
        var chars = value.ToCharArray();
        for (var index = 0; index < chars.Length; index++) if (mask[index] && !char.IsWhiteSpace(chars[index])) chars[index] = '•';
        return new string(chars);
    }

    private static void Mark(Regex regex, string value, bool[] mask)
    {
        foreach (Match match in regex.Matches(value))
            for (var index = match.Index; index < match.Index + match.Length; index++) mask[index] = true;
    }

    private static void MarkGroup(Regex regex, string groupName, string value, bool[] mask)
    {
        foreach (Match match in regex.Matches(value))
        {
            var group = match.Groups[groupName];
            for (var index = group.Index; index < group.Index + group.Length; index++) mask[index] = true;
        }
    }

    [GeneratedRegex(@"(?<![\w.])[\w.%+\-]+@[\w.\-]+\.[A-Za-z]{2,}(?!\w)", RegexOptions.CultureInvariant)]
    private static partial Regex Email();
    [GeneratedRegex(@"(?<!\d)(?:\+?84|0)(?:[\s().\-]*\d){8,10}(?!\d)", RegexOptions.CultureInvariant)]
    private static partial Regex Phone();
    [GeneratedRegex(@"(?<!\d)\d{9,12}(?!\d)", RegexOptions.CultureInvariant)]
    private static partial Regex LongNumber();
    [GeneratedRegex(@"(?<![\da-f])[\da-f]{8}-[\da-f]{4}-[1-5][\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}(?![\da-f])", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Uuid();
    [GeneratedRegex(@"https?://[^\s]+", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant)]
    private static partial Regex Url();
    [GeneratedRegex(@"(?<![\w-])eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}(?:\.[A-Za-z0-9_-]{10,})?(?![\w-])", RegexOptions.CultureInvariant)]
    private static partial Regex Jwt();
    [GeneratedRegex(@"(?i:\b(?:họ\s*tên|tên)\s*(?:là|:)\s*)(?<value>\p{Lu}[\p{L}'-]*(?:\s+\p{Lu}[\p{L}'-]*){1,4})", RegexOptions.CultureInvariant)]
    private static partial Regex ExplicitName();
}
