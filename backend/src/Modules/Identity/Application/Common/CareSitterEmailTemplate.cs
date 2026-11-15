using System.Net;

namespace CareSitter.Modules.Identity.Application;

/// <summary>
/// Mẫu email dùng màu xanh chủ đạo của ứng dụng, với CSS nội tuyến cho trình đọc email.
/// </summary>
internal static class CareSitterEmailTemplate
{
    public static string Code(string title, string description, string code, int expiresInMinutes)
        => Build(title, $"""
            <p style="color:#536471;font-size:15px;margin:0 0 24px;line-height:1.6;">
              {WebUtility.HtmlEncode(description)}
              Mã có hiệu lực trong <strong>{expiresInMinutes} phút</strong>.
            </p>
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 24px;">
              <tr>
                <td align="center" bgcolor="#E6F4F1" style="background-color:#E6F4F1;border:1px solid #006B5B;border-radius:10px;padding:24px 12px;">
                  <strong style="font-size:36px;line-height:1.2;font-weight:700;letter-spacing:6px;color:#006B5B;font-family:'Courier New',monospace;white-space:nowrap;">{WebUtility.HtmlEncode(code)}</strong>
                </td>
              </tr>
            </table>
            <p style="color:#536471;font-size:13px;margin:0;line-height:1.6;">
              Nếu bạn không yêu cầu mã này, hãy bỏ qua email này.
              Không chia sẻ mã này với bất kỳ ai.
            </p>
            """);

    public static string Notification(string title, string message)
        => Build(title, $"""
            <p style="color:#536471;font-size:15px;margin:0;line-height:1.6;">{WebUtility.HtmlEncode(message)}</p>
            """);

    private static string Build(string title, string contentHtml) => $"""
        <!DOCTYPE html>
        <html lang="vi">
        <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
        <body style="margin:0;padding:0;background-color:#F5F3EE;font-family:'Segoe UI',Arial,sans-serif;">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#F5F3EE" style="background-color:#F5F3EE;">
            <tr><td align="center" style="padding:32px 12px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#FFFFFF" style="width:100%;max-width:480px;background-color:#FFFFFF;border-radius:12px;">
                <tr>
                  <td align="center" bgcolor="#006B5B" style="background-color:#006B5B;padding:28px 24px;border-radius:12px 12px 0 0;">
                    <h1 style="color:#FFFFFF;margin:0;font-size:24px;line-height:1.3;font-weight:700;">CareSitter</h1>
                    <p style="color:#FFFFFF;margin:8px 0 0;font-size:14px;line-height:1.5;">{WebUtility.HtmlEncode(title)}</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:32px 24px;">
                    <p style="color:#0D1117;font-size:16px;line-height:1.5;margin:0 0 20px;">Xin chào,</p>
                    {contentHtml}
                  </td>
                </tr>
                <tr>
                  <td align="center" bgcolor="#E6F4F1" style="background-color:#E6F4F1;padding:20px 24px;border-radius:0 0 12px 12px;">
                    <p style="color:#536471;font-size:12px;line-height:1.5;margin:0;">© CareSitter. Bảo lưu mọi quyền.</p>
                  </td>
                </tr>
              </table>
            </td></tr>
          </table>
        </body>
        </html>
        """;
}
