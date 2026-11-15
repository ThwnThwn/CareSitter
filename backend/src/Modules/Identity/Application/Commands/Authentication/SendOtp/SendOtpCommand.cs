using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.SendOtp;

/// <summary>
/// Yêu cầu gửi mã OTP xác thực đến địa chỉ email.
/// </summary>
/// <param name="Email">Địa chỉ email nhận mã OTP.</param>
public sealed record SendOtpCommand(string Email) : IRequest<Result>;
