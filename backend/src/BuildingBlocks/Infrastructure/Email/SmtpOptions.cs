namespace CareSitter.Infrastructure.Email;

/// <summary>
/// Tuỳ chọn cấu hình SMTP (Gmail hoặc bất kỳ SMTP provider nào).
/// Bind từ section <c>Smtp</c> trong appsettings.json.
/// </summary>
public sealed class SmtpOptions
{
    public const string SectionName = "Smtp";

    /// <summary>SMTP host. Mặc định: smtp.gmail.com.</summary>
    public string Host { get; set; } = "smtp.gmail.com";

    /// <summary>SMTP port với STARTTLS. Mặc định: 587.</summary>
    public int Port { get; set; } = 587;

    /// <summary>Địa chỉ Gmail (user@gmail.com).</summary>
    public string UserName { get; set; } = string.Empty;

    /// <summary>
    /// Gmail App Password (KHÔNG phải password thường).
    /// Tạo tại: https://myaccount.google.com/apppasswords
    /// </summary>
    public string Password { get; set; } = string.Empty;

    /// <summary>Tên hiển thị trong trường From của email.</summary>
    public string FromName { get; set; } = "CareSitter";

    /// <summary>Thời gian tối đa cho một kết nối/giao dịch SMTP.</summary>
    public int TimeoutSeconds { get; set; } = 30;
}
