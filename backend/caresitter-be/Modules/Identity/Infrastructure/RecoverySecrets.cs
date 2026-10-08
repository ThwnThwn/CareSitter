using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed record RecoveryMail(string? Recipient, string Subject, string Html);

internal sealed class RecoverySecrets(IOptions<RecoveryOptions> options)
{
    private byte[] Key => Encoding.UTF8.GetBytes(options.Value.SecretKey);
    public string Digest(string value) => Convert.ToHexString(HMACSHA256.HashData(Key, Encoding.UTF8.GetBytes(value)));
    public string CodeHash(Guid id, string code) => Digest($"code:{id:D}:{code}");
    public static string TokenHash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
    public bool Matches(Guid id, string code, string stored) => CryptographicOperations.FixedTimeEquals(
        Encoding.ASCII.GetBytes(CodeHash(id, code)), Encoding.ASCII.GetBytes(stored));
    public string Encrypt(RecoveryMail mail)
    {
        var plain = JsonSerializer.SerializeToUtf8Bytes(mail);
        var nonce = RandomNumberGenerator.GetBytes(12);
        var tag = new byte[16]; var cipher = new byte[plain.Length];
        using var aes = new AesGcm(HMACSHA256.HashData(Key, "recovery-email-payload"u8.ToArray()), 16);
        aes.Encrypt(nonce, plain, cipher, tag);
        return Convert.ToBase64String(nonce.Concat(tag).Concat(cipher).ToArray());
    }
    public RecoveryMail Decrypt(string payload)
    {
        var bytes = Convert.FromBase64String(payload);
        var plain = new byte[bytes.Length - 28];
        using var aes = new AesGcm(HMACSHA256.HashData(Key, "recovery-email-payload"u8.ToArray()), 16);
        aes.Decrypt(bytes.AsSpan(0, 12), bytes.AsSpan(28), bytes.AsSpan(12, 16), plain);
        return JsonSerializer.Deserialize<RecoveryMail>(plain)!;
    }
}
