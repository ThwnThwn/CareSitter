using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.LoginWithPassword;

/// <summary>
/// Yêu cầu đăng nhập tài khoản bằng Email và mật khẩu.
/// </summary>
/// <param name="Email">Địa chỉ email đăng nhập.</param>
/// <param name="Password">Mật khẩu của tài khoản.</param>
/// <param name="RequiredRole">Vai trò bắt buộc cho ứng dụng đang đăng nhập, ví dụ CUSTOMER hoặc CAREGIVER.</param>
public sealed record LoginWithPasswordCommand(
    string Email,
    string Password,
    string? RequiredRole = null
) : IRequest<Result<LoginResponse>>;
