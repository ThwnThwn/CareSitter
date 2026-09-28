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
        var htmlBody = BuildEmailHtml(code);

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

    /// <summary>
    /// Tạo nội dung HTML cho email OTP với giao diện đẹp.
    /// </summary>
    private static string BuildEmailHtml(string code) => $"""
        <!DOCTYPE html>
        <html lang="vi">
        <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body style="margin:0;padding:0;background:#f4f6f8;font-family:'Segoe UI',Arial,sans-serif;">
          <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 0;">
            <tr><td align="center">
              <table width="480" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.08);">
                <!-- Header -->
                <tr>
                  <td style="background:linear-gradient(135deg,#667eea,#764ba2);padding:32px;text-align:center;">
                    <h1 style="color:#fff;margin:0;font-size:24px;font-weight:700;">CareSitter</h1>
                    <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">Xác thực tài khoản</p>
                  </td>
                </tr>
                <!-- Body -->
                <tr>
                  <td style="padding:40px 32px;">
                    <p style="color:#333;font-size:16px;margin:0 0 24px;">Xin chào,</p>
                    <p style="color:#555;font-size:15px;margin:0 0 32px;line-height:1.6;">
                      Đây là mã OTP để đăng nhập vào tài khoản <strong>CareSitter</strong> của bạn.
                      Mã có hiệu lực trong <strong>10 phút</strong>.
                    </p>
                    <!-- OTP Box -->
                    <div style="background:#f0f4ff;border:2px dashed #667eea;border-radius:10px;padding:24px;text-align:center;margin:0 0 32px;">
                      <span style="font-size:40px;font-weight:800;letter-spacing:12px;color:#667eea;font-family:'Courier New',monospace;">{code}</span>
                    </div>
                    <p style="color:#888;font-size:13px;margin:0;line-height:1.6;">
                      Nếu bạn không yêu cầu mã này, hãy bỏ qua email này.
                      Không chia sẻ mã này với bất kỳ ai.
                    </p>
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="background:#f9f9f9;padding:20px 32px;text-align:center;border-top:1px solid #eee;">
                    <p style="color:#aaa;font-size:12px;margin:0;">© 2025 CareSitter. All rights reserved.</p>
                  </td>
                </tr>
              </table>
            </td></tr>
          </table>
        </body>
        </html>
        """;
}
