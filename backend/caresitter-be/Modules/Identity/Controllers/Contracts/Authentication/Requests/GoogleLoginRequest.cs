using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Request body công khai cho đăng nhập Google. Client chỉ được gửi ID token;
/// role được endpoint phía server quyết định theo ứng dụng.
/// </summary>
/// <param name="IdToken">
/// Google ID Token nhận được từ Google Sign-In SDK trên client.
/// Token này được verify phía server bằng Google public keys.
/// </param>
public sealed record GoogleLoginRequest(string IdToken);
