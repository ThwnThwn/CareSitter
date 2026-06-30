namespace CareSitter.Infrastructure.Security;

/// <summary>
/// Ma hoa du lieu nhay cam (CCCD, so TK) + HMAC hash chong trung. Key tu KMS/cau hinh.
/// </summary>
public interface IEncryptionService
{
    string Encrypt(string plaintext);
    string Decrypt(string ciphertext);

    /// <summary>HMAC deterministic de check trung (vd cccd_hash) ma khong lo gia tri goc.</summary>
    string Hmac(string value);
}
