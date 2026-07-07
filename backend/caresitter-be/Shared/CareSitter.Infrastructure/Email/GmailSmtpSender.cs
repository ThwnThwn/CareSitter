using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MimeKit;

namespace CareSitter.Infrastructure.Email;

/// <summary>
/// Gửi email thông qua Gmail SMTP sử dụng MailKit.
/// Cấu hình qua <see cref="SmtpOptions"/> (section "Smtp" trong appsettings.json).
/// </summary>
internal sealed class GmailSmtpSender : IEmailSender
{
    private readonly SmtpOptions _opts;
    private readonly ILogger<GmailSmtpSender> _logger;

    public GmailSmtpSender(IOptions<SmtpOptions> opts, ILogger<GmailSmtpSender> logger)
    {
        _opts = opts.Value;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task SendAsync(string to, string subject, string htmlBody, CancellationToken ct = default)
    {
        var fromAddress = _opts.UserName.Trim();
        var appPassword = string.Concat(_opts.Password.Where(c => !char.IsWhiteSpace(c)));

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_opts.FromName.Trim(), fromAddress));
        message.To.Add(MailboxAddress.Parse(to));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = htmlBody };

        using var smtp = new SmtpClient
        {
            CheckCertificateRevocation = true,
            Timeout = checked(_opts.TimeoutSeconds * 1_000)
        };

        try
        {
            // Gmail submission dùng STARTTLS trên port 587.
            await smtp.ConnectAsync(_opts.Host, _opts.Port, SecureSocketOptions.StartTls, ct);
            await smtp.AuthenticateAsync(fromAddress, appPassword, ct);
            await smtp.SendAsync(message, ct);

            // Không log địa chỉ người nhận hoặc nội dung OTP.
            _logger.LogInformation("Gmail SMTP đã gửi email thành công.");
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Gmail SMTP không thể gửi email.");
            throw;
        }
        finally
        {
            if (smtp.IsConnected)
            {
                try
                {
                    await smtp.DisconnectAsync(true, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Không thể đóng kết nối Gmail SMTP đúng cách.");
                }
            }
        }
    }
}
