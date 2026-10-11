using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CareSitter.Modules.Identity.Application.Authentication.Dtos.Requests;
using CareSitter.Modules.Identity.Application.Authentication.Mapping;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.LoginWithPassword;
using CareSitter.Modules.Identity.Application.Logout;
using CareSitter.Modules.Identity.Application.RefreshToken;
using CareSitter.Modules.Identity.Application.Register;
using CareSitter.Modules.Identity.Application.SendOtp;
using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace CareSitter.Modules.Identity.Controllers;

/// <summary>
/// Handles authentication requests. Root route: /api/v1/auth.
/// </summary>
[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IMediator _mediator;

    public AuthController(IMediator mediator)
    {
        _mediator = mediator;
    }

    // Dịch vụ khác kiểm phiên qua JWT pipeline hiện hành, không đọc DB Identity.
    [Authorize]
    [HttpGet("session")]
    [EnableRateLimiting("auth-session")]
    public IActionResult Session() => NoContent();

    /// <summary>
    /// Sends a 6-digit OTP to the requested email address.
    /// </summary>
    [HttpPost("send-otp")]
    [EnableRateLimiting("auth-send-otp")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SendOtp([FromBody] SendOtpRequest request)
    {
        var result = await _mediator.Send(request.ToCommand());
        return result.IsSuccess ? Ok() : HandleFailure(result.Error);
    }

    /// <summary>
    /// Logs in with email and OTP, returning access and refresh tokens.
    /// </summary>
    [HttpPost("login")]
    [EnableRateLimiting("auth-login")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var result = await _mediator.Send(request.ToCommand());
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
    public async Task<IActionResult> Logout([FromBody] LogoutRequest? body = null)
    {
        var jti = User.FindFirstValue(JwtRegisteredClaimNames.Jti);
        var exp = User.FindFirstValue(JwtRegisteredClaimNames.Exp);
        var sub = User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue(ClaimTypes.NameIdentifier);
        var sid = User.FindFirstValue("sid");

        if (string.IsNullOrWhiteSpace(jti) ||
            string.IsNullOrWhiteSpace(exp) ||
            !long.TryParse(exp, out var expUnixSeconds) ||
            !Guid.TryParse(sub, out var userId) ||
            !Guid.TryParse(sid, out var sessionId))
        {
            return HandleFailure(Error.Validation(
                "auth.invalid_token",
                "Access token không hợp lệ hoặc thiếu thông tin hết hạn."));
        }

        var expiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(expUnixSeconds);
        // Gửi refreshToken (nếu có) để server revoke session bền vững trong PostgreSQL.
        var result = await _mediator.Send(new LogoutCommand(
            jti, expiresAtUtc, userId, sessionId, body?.RefreshToken));

        return result.IsSuccess ? NoContent() : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng ký tài khoản người dùng mới (CUSTOMER hoặc CAREGIVER).
    /// Trả về JWT Access Token và Refresh Token khi thành công.
    /// </summary>
    /// <param name="request">Thông tin đăng ký gồm Phone, FullName, Email và Roles. Password là tuỳ chọn.</param>
    [HttpPost("register")]
    [EnableRateLimiting("auth-register")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var result = await _mediator.Send(request.ToCommand());
        return result.IsSuccess
            ? Created("api/v1/auth/login", result.Value)
            : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng nhập bằng Email và mật khẩu.
    /// Yêu cầu tài khoản đã thiết lập mật khẩu khi đăng ký.
    /// </summary>
    /// <param name="request">Email và mật khẩu.</param>
    [HttpPost("login/password")]
    [EnableRateLimiting("auth-login")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LoginWithPassword([FromBody] LoginWithPasswordRequest request)
    {
        var result = await _mediator.Send(request.ToCommand());
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    /// <summary>
    /// Làm mới Access Token và Refresh Token từ refresh token hiện tại.
    /// Chiến lược PostgreSQL-authoritative với Redis lookup cache:
    ///   - Client chỉ gửi refreshToken (không cần accessToken).
    ///   - Server kiểm tra session DB, revoke token cũ và tạo session mới trong transaction.
    ///   - Redis miss sẽ fallback DB và tự làm ấm lại cache.
    /// </summary>
    [HttpPost("refresh")]
    [EnableRateLimiting("auth-refresh")]
    [ProducesResponseType(typeof(RefreshTokenResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Refresh([FromBody] RefreshTokenRequest request)
    {
        var result = await _mediator.Send(request.ToCommand());
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng nhập hoặc đăng ký từ Customer app bằng Google Account.
    /// Role CUSTOMER do server gán, không nhận từ request body.
    /// </summary>
    [HttpPost("google/customer")]
    [EnableRateLimiting("auth-login")]
    [ProducesResponseType(typeof(GoogleLoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GoogleCustomer([FromBody] GoogleLoginRequest request)
    {
        var result = await _mediator.Send(new GoogleLoginCommand(
            request.IdToken, GoogleLoginRolePolicy.Customer));
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    /// <summary>
    /// Đăng nhập hoặc đăng ký từ Caregiver app bằng Google Account.
    /// Role CAREGIVER do server gán; caregiver mới vẫn phải hoàn tất KYC.
    /// </summary>
    [HttpPost("google/caregiver")]
    [EnableRateLimiting("auth-login")]
    [ProducesResponseType(typeof(GoogleLoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GoogleCaregiver([FromBody] GoogleLoginRequest request)
    {
        var result = await _mediator.Send(new GoogleLoginCommand(
            request.IdToken, GoogleLoginRolePolicy.Caregiver));
        return result.IsSuccess ? Ok(result.Value) : HandleFailure(result.Error);
    }

    private IActionResult HandleFailure(Error error) => error.Type switch
    {
        ErrorType.Validation  => BadRequest(CreateProblem(error)),
        ErrorType.NotFound    => NotFound(CreateProblem(error)),
        ErrorType.Conflict    => Conflict(CreateProblem(error)),
        ErrorType.Forbidden   => StatusCode(StatusCodes.Status403Forbidden, CreateProblem(error)),
        ErrorType.Unavailable => StatusCode(StatusCodes.Status503ServiceUnavailable, CreateProblem(error)),
        _                     => BadRequest(CreateProblem(error))
    };

    private static ProblemDetails CreateProblem(Error error) => new()
    {
        Title  = error.Code,
        Detail = error.Message,
    };
}
