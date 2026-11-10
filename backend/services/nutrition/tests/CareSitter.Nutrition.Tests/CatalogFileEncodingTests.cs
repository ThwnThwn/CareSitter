using System.Text;
using System.Text.RegularExpressions;

namespace CareSitter.Nutrition.Tests;

// Catalog JSON is reviewed and hashed byte-for-byte, so it must stay plain UTF-8.
// Re-saving it through Windows PowerShell 5 (Get-Content without -Encoding) turns
// "dưỡng" into "dÆ°á»¡ng" while keeping the JSON valid, which no schema check catches.
public sealed class CatalogFileEncodingTests
{
    // UTF-8 lead bytes C3/C4/C6/E1 read as Windows-1252, followed by a continuation-byte
    // character. Plain Vietnamese never puts these pairs next to each other.
    private static readonly Regex Mojibake = new(
        "Ã[ -¿]|Ä[\u0080-¿‘’]|Æ[ -¿]|á[º»]",
        RegexOptions.CultureInvariant);

    public static TheoryData<string> CatalogFiles()
    {
        var data = new TheoryData<string>();
        var root = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog");
        foreach (var file in Directory.EnumerateFiles(root, "*.json", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
            data.Add(Path.GetRelativePath(root, file));
        return data;
    }

    [Theory]
    [MemberData(nameof(CatalogFiles))]
    public async Task Catalog_json_is_strict_utf8_without_bom_or_mojibake(string relativePath)
    {
        var path = Path.Combine(ServiceArchitectureTests.FindRoot(), "catalog", relativePath);
        var bytes = await File.ReadAllBytesAsync(path);

        Assert.False(bytes is [0xEF, 0xBB, 0xBF, ..], $"{relativePath} starts with a UTF-8 BOM.");
        var text = new UTF8Encoding(false, throwOnInvalidBytes: true).GetString(bytes);
        var match = Mojibake.Match(text);
        Assert.False(match.Success, $"{relativePath} contains double-encoded text near '{match.Value}'.");
    }
}
