using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.LoginWithPassword;
using CareSitter.Modules.Identity.Application.Logout;
using CareSitter.Modules.Identity.Application.RefreshToken;
using CareSitter.Modules.Identity.Application.Register;
using CareSitter.Modules.Identity.Application.SendOtp;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Controllers;

/// <summary>
/// Body cho POST /auth/logout.
/// RefreshToken là tùy chọn — nếu gửi, server sẽ revoke session trong PostgreSQL.
/// </summary>
public sealed record LogoutRequest(string? RefreshToken = null);
