using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Login;

/// <summary>
/// Yêu cầu đăng nhập tài khoản bằng email và mã OTP đã được gửi đến email.
/// </summary>
/// <param name="Email">Địa chỉ email đăng nhập.</param>
/// <param name="Otp">Mã OTP 6 chữ số nhận được qua email.</param>
public sealed record LoginCommand(string Email, string Otp) : IRequest<Result<LoginResponse>>;

/// <summary>
/// Phản hồi kết quả đăng nhập chứa thông tin tokens và người dùng.
/// </summary>
/// <param name="AccessToken">JWT Access Token dùng trong Authorization header của các request sau.</param>
/// <param name="RefreshToken">Refresh Token dùng để cấp lại Access Token mới.</param>
/// <param name="UserId">ID của người dùng đăng nhập.</param>
/// <param name="Roles">Danh sách vai trò (CUSTOMER, CAREGIVER, ADMIN) của người dùng.</param>
/// <param name="DisplayName">Tên hiển thị của người dùng.</param>
public sealed record LoginResponse(
    string AccessToken,
    string RefreshToken,
    Guid UserId,
    string[] Roles,
    string? DisplayName
);
