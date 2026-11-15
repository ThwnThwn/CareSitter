using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Application;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.Extensions.Logging;
using System.Security.Cryptography;

namespace CareSitter.Modules.Identity.Application.SendOtp;

/// <summary>
/// Xử lý yêu cầu gửi OTP xác thực đến email người dùng.
/// </summary>
internal sealed class SendOtpHandler : IRequestHandler<SendOtpCommand, Result>
{
    // OTP hết hạn sau 10 phút
    private static readonly TimeSpan OtpTtl = TimeSpan.FromMinutes(10);

    private readonly IOtpStore _otpStore;
    private readonly IEmailSender _emailSender;
    private readonly ILogger<SendOtpHandler> _logger;
    private readonly IAuthenticationAttemptLimiter _attemptLimiter;

    public SendOtpHandler(
        IOtpStore otpStore,
        IEmailSender emailSender,
        ILogger<SendOtpHandler> logger,
        IAuthenticationAttemptLimiter attemptLimiter)
    {
        _otpStore = otpStore;
        _emailSender = emailSender;
        _logger = logger;
        _attemptLimiter = attemptLimiter;
    }

    /// <summary>
    /// Sinh OTP, lưu vào Redis Distributed Cache và gửi đến email người dùng.
    /// Rate limit: không gửi thêm nếu đã có OTP còn hiệu lực.
    /// </summary>
    public async Task<Result> Handle(SendOtpCommand request, CancellationToken ct)
    {
        var email = request.Email?.Trim().ToLowerInvariant() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(email))
            return Error.Validation("otp.email_required", "Địa chỉ email là bắt buộc.");

        if (!await _attemptLimiter.TryConsumeAsync(
                "otp-send", email, 5, TimeSpan.FromHours(1), ct))
        {
            return Error.Validation("otp.rate_limit",
                "Đã vượt quá số lần yêu cầu OTP. Vui lòng thử lại sau.");
        }

        // Chặn spam trong 60 giây nhưng vẫn cho phép gửi mã mới trước khi OTP cũ
        // hết hạn 10 phút. Mã mới sẽ thay thế mã cũ.
        if (await _otpStore.IsCoolingDownAsync(email, ct))
        {
            return Error.Validation("otp.rate_limit", "Vui lòng chờ 60 giây trước khi yêu cầu mã mới.");
        }

        // Sinh OTP 6 chữ số bảo mật bằng RandomNumberGenerator
        var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

        // Lưu OTP vào Redis với TTL là 10 phút
        await _otpStore.SaveAsync(email, code, OtpTtl, TimeSpan.FromSeconds(60), ct);

        // Gửi email
        var subject = "Mã xác thực CareSitter của bạn";
        var htmlBody = CareSitterEmailTemplate.Code(
            "Xác thực tài khoản",
            "Đây là mã OTP để đăng nhập vào tài khoản CareSitter của bạn.",
            code, (int)OtpTtl.TotalMinutes);

        try
        {
            await _emailSender.SendAsync(email, subject, htmlBody, ct);
        }
        catch (Exception ex)
        {
            // Không giữ OTP mà người dùng chưa nhận được qua email.
            try
            {
                await _otpStore.RemoveAsync(email, CancellationToken.None);
            }
            catch (Exception cleanupException)
            {
                _logger.LogError(cleanupException, "Không thể xóa OTP sau khi gửi email thất bại.");
            }

            if (ex is OperationCanceledException && ct.IsCancellationRequested)
                throw;

            _logger.LogError(ex, "Không thể gửi OTP qua Gmail SMTP.");
            return Error.Unavailable("otp.delivery_failed", "Không thể gửi email OTP lúc này. Vui lòng thử lại sau.");
        }

        return Result.Success();
    }

}
