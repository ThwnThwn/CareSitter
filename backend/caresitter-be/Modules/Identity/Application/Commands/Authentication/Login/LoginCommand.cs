using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Login;

/// <summary>
/// Yêu cầu đăng nhập tài khoản bằng email và mã OTP đã được gửi đến email.
/// </summary>
/// <param name="Email">Địa chỉ email đăng nhập.</param>
/// <param name="Otp">Mã OTP 6 chữ số nhận được qua email.</param>
/// <param name="RequiredRole">Vai trò bắt buộc cho ứng dụng đang đăng nhập, ví dụ CUSTOMER hoặc CAREGIVER.</param>
public sealed record LoginCommand(
    string Email,
    string Otp,
    string? RequiredRole = null
) : IRequest<Result<LoginResponse>>;
