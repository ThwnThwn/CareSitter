using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.LoginWithPassword;
using CareSitter.Modules.Identity.Application.Logout;
using CareSitter.Modules.Identity.Application.Register;
using CareSitter.Modules.Identity.Application.SendOtp;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Identity.Controllers;

/// <summary>
/// Handles authentication requests. Root route: /api/v1/auth.
/// </summary>
[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly ISender _sender;

    public AuthController(ISender sender) => _sender = sender;

    /// <summary>
    /// Sends a 6-digit OTP to the requested email address.
    /// </summary>
    [HttpPost("send-otp")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SendOtp([FromBody] SendOtpCommand command)
    {
        var result = await _sender.Send(command);
        return result.IsSuccess ? Ok() : HandleFailure(result.Error);
    }

    /// <summary>
    /// Logs in with email and OTP, returning access and refresh tokens.
    /// </summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Login([FromBody] LoginCommand command)
    {
        var result = await _sender.Send(command);
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    /// <summary>
    /// Logs out the current session by revoking the current access token until it expires.
    /// The client should also remove locally stored access and refresh tokens after success.
    /// </summary>
    [Authorize]
    [HttpPost("logout")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Logout()
    {
        var jti = User.FindFirstValue(JwtRegisteredClaimNames.Jti);
        var exp = User.FindFirstValue(JwtRegisteredClaimNames.Exp);

        if (string.IsNullOrWhiteSpace(jti) ||
            string.IsNullOrWhiteSpace(exp) ||
            !long.TryParse(exp, out var expUnixSeconds))
        {
            return HandleFailure(Error.Validation(
                "auth.invalid_token",
                "Access token khong hop le hoac thieu thong tin het han."));
        }

        var expiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(expUnixSeconds);
        var result = await _sender.Send(new LogoutCommand(jti, expiresAtUtc));

        return result.IsSuccess ? NoContent() : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng ký tài khoản người dùng mới (CUSTOMER, CAREGIVER hoặc ADMIN).
    /// Trả về JWT Access Token và Refresh Token khi thành công.
    /// </summary>
    /// <param name="command">Thông tin đăng ký gồm Phone, FullName, Email và Roles. Password là tuỳ chọn.</param>
    [HttpPost("register")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register([FromBody] RegisterCommand command)
    {
        var result = await _sender.Send(command);
        return result.IsSuccess
            ? Created("api/v1/auth/login", result.Value)
            : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng nhập bằng Email và mật khẩu.
    /// Yêu cầu tài khoản đã thiết lập mật khẩu khi đăng ký.
    /// </summary>
    /// <param name="command">Email và mật khẩu.</param>
    [HttpPost("login/password")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LoginWithPassword([FromBody] LoginWithPasswordCommand command)
    {
        var result = await _sender.Send(command);
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng nhập hoặc đăng ký bằng Google Account.
    /// Gửi Google ID Token nhận được từ Google Sign-In SDK trên client.
    /// Nếu tài khoản chưa tồn tại sẽ tự động được tạo với role mặc định CUSTOMER.
    /// </summary>
    /// <param name="command">Google ID Token và danh sách vai trò (tuỳ chọn cho lần đăng ký đầu).</param>
    [HttpPost("google/callback")]
    [ProducesResponseType(typeof(GoogleLoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GoogleCallback([FromBody] GoogleLoginCommand command)
    {
        var result = await _sender.Send(command);
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    private IActionResult HandleFailure(Error error) => error.Type switch
    {
        ErrorType.Validation => BadRequest(CreateProblem(error)),
        ErrorType.NotFound => NotFound(CreateProblem(error)),
        ErrorType.Conflict => Conflict(CreateProblem(error)),
        ErrorType.Forbidden => Forbid(),
        ErrorType.Unavailable => StatusCode(StatusCodes.Status503ServiceUnavailable, CreateProblem(error)),
        _ => BadRequest(CreateProblem(error))
    };

    private static ProblemDetails CreateProblem(Error error) => new()
    {
        Title = error.Code,
        Detail = error.Message,
    };
}