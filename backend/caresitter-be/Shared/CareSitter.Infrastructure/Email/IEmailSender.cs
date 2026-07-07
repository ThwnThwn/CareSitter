namespace CareSitter.Infrastructure.Email;

/// <summary>
/// Service gửi email. Inject interface này để gửi email trong Application layer.
/// </summary>
public interface IEmailSender
{
    /// <summary>
    /// Gửi email với nội dung HTML.
    /// </summary>
    /// <param name="to">Địa chỉ email người nhận.</param>
    /// <param name="subject">Tiêu đề email.</param>
    /// <param name="htmlBody">Nội dung HTML của email.</param>
    /// <param name="ct">Cancellation token.</param>
    Task SendAsync(string to, string subject, string htmlBody, CancellationToken ct = default);
}
