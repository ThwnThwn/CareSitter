using CareSitter.Contracts.Services;
using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Infrastructure.Security;

/// <summary>
/// AES-256-CBC + HMAC-SHA256. MVP doc key tu cấu hình; production thay bang KMS/envelope encryption.
/// Dinh dang ciphertext: base64(iv) + ':' + base64(cipher).
/// </summary>
public sealed class AesEncryptionService : IEncryptionService
{
    private readonly byte[] _key;
    private readonly byte[] _hmacKey;

    public AesEncryptionService(EncryptionOptions options)
    {
        _key = DeriveKey(options.EncryptionKey, "enc");
        _hmacKey = DeriveKey(options.EncryptionKey, "mac");
    }

    public string Encrypt(string plaintext)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.GenerateIV();

        using var encryptor = aes.CreateEncryptor();
        byte[] plain = Encoding.UTF8.GetBytes(plaintext);
        byte[] cipher = encryptor.TransformFinalBlock(plain, 0, plain.Length);

        return $"{Convert.ToBase64String(aes.IV)}:{Convert.ToBase64String(cipher)}";
    }

    public string Decrypt(string ciphertext)
    {
        string[] parts = ciphertext.Split(':', 2);
        if (parts.Length != 2)
            throw new FormatException("Ciphertext khong dung dinh dang iv:cipher.");

        byte[] iv = Convert.FromBase64String(parts[0]);
        byte[] cipher = Convert.FromBase64String(parts[1]);

        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = iv;

        using var decryptor = aes.CreateDecryptor();
        byte[] plain = decryptor.TransformFinalBlock(cipher, 0, cipher.Length);
        return Encoding.UTF8.GetString(plain);
    }

    public string Hmac(string value)
    {
        using var hmac = new HMACSHA256(_hmacKey);
        byte[] hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(hash);
    }

    private static byte[] DeriveKey(string secret, string purpose)
    {
        using var sha = SHA256.Create();
        return sha.ComputeHash(Encoding.UTF8.GetBytes($"{purpose}:{secret}"));
    }
}

public sealed class EncryptionOptions
{
    public const string SectionName = "Encryption";

    /// <summary>Khoa bi mat goc (production: lay tu KMS/secret manager, KHONG hardcode).</summary>
    public string EncryptionKey { get; set; } = string.Empty;
}
