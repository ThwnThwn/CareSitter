namespace CareSitter.Modules.Catalog.Domain;

public static class ReportPdfPolicy
{
    public const int MaxBytes = 10 * 1024 * 1024;
    public static bool IsPdf(byte[] bytes) => bytes.Length is >= 16 and <= MaxBytes &&
        bytes.AsSpan(0, 5).SequenceEqual("%PDF-"u8) &&
        bytes.AsSpan(Math.Max(0, bytes.Length - 1024)).IndexOf("%%EOF"u8) >= 0;
}
