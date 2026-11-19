using System.Security.Cryptography;
using System.Text;

namespace CareSitter.Contracts.Services;

public static class PushTargetKey
{
    public static string FromToken(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
