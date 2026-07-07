using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Email;

/// <summary>
/// Extension methods đăng ký Email service vào DI container.
/// </summary>
public static class EmailServiceRegistration
{
    /// <summary>
    /// Đăng ký <see cref="IEmailSender"/> (Gmail SMTP) vào DI container.
    /// Đọc config từ section <c>Smtp</c> trong appsettings.json.
    /// </summary>
    public static IServiceCollection AddEmailSender(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOptions<SmtpOptions>()
            .Bind(configuration.GetSection(SmtpOptions.SectionName))
            .Validate(options => !string.IsNullOrWhiteSpace(options.Host),
                "Smtp:Host is required.")
            .Validate(options => options.Port is > 0 and <= 65535,
                "Smtp:Port must be between 1 and 65535.")
            .Validate(options => options.Host.Equals("smtp.gmail.com", StringComparison.OrdinalIgnoreCase),
                "Only Gmail SMTP (smtp.gmail.com) is supported.")
            .Validate(options => MimeKit.MailboxAddress.TryParse(options.UserName, out _),
                "Smtp:UserName must be a valid email address.")
            .Validate(options => !string.IsNullOrWhiteSpace(options.Password),
                "Smtp:Password is required and must be a Gmail App Password.")
            .Validate(options => !string.IsNullOrWhiteSpace(options.FromName),
                "Smtp:FromName is required.")
            .Validate(options => options.TimeoutSeconds is >= 5 and <= 120,
                "Smtp:TimeoutSeconds must be between 5 and 120 seconds.")
            .ValidateOnStart();

        services.AddTransient<IEmailSender, GmailSmtpSender>();
        return services;
    }
}
