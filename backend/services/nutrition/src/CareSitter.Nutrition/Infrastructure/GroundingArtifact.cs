using System.Security.Cryptography;

namespace CareSitter.Nutrition.Infrastructure;

internal static class GroundingArtifact
{
    private const long MaximumArtifactBytes = 32 * 1024 * 1024;

    public static byte[] ReadVerified(string path, string expected)
    {
        if (!Path.IsPathFullyQualified(path) || !File.Exists(path) ||
            new FileInfo(path).Length is 0 or > MaximumArtifactBytes)
            throw new InvalidOperationException("Grounding artifact is unavailable or exceeds the size limit.");
        var bytes = File.ReadAllBytes(path);
        if (!Convert.ToHexString(SHA256.HashData(bytes)).Equals(expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Grounding artifact digest mismatch.");
        return bytes;
    }
}
