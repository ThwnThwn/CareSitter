using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.Register;

/// <summary>
/// Yêu cầu đăng ký tài khoản người dùng mới.
/// </summary>
/// <param name="Email">Địa chỉ email đăng ký (dùng làm định danh chính).</param>
/// <param name="FullName">Họ và tên đầy đủ.</param>
/// <param name="Roles">Danh sách vai trò đăng ký (ví dụ: CUSTOMER, CAREGIVER).</param>
/// <param name="Password">
/// Mật khẩu (tuỳ chọn). Nếu không cung cấp, tài khoản chỉ đăng nhập được bằng OTP hoặc Google.
/// Tối thiểu 8 ký tự, có ít nhất 1 chữ hoa và 1 chữ số.
/// </param>
/// <param name="ConfirmPassword">Xác nhận lại mật khẩu — phải khớp với Password.</param>
/// <param name="Phone">Số điện thoại liên hệ của người dùng.</param>
public sealed record RegisterCommand(
    string Email,
    string FullName,
    string[] Roles,
    string? Password = null,
    string? ConfirmPassword = null,
    string? Phone = null
) : IRequest<Result<LoginResponse>>;
