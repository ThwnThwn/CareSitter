using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.NotificationWorker.Application.Ports;
using CareSitter.Push;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace CareSitter.NotificationWorker.Infrastructure.Delivery;

/// <summary>Push/email adapters with explicit failure reporting and no database access.</summary>
public sealed class NotificationSender(IConfiguration config) : INotificationSender
{
    private readonly FirebasePushTransport _push = new(config);

    /// <summary>Delivers bounded provider requests. Provider acceptance is not an exactly-once receipt.</summary>
    public async Task<HandlerResult> SendAsync(string channel, DeliveryClaim claim, Func<string[], CancellationToken, Task> checkpoint, CancellationToken ct)
    {
        if (channel == "push")
        {
            var result = await _push.SendAsync(claim.PushTokens ?? [], claim.Title, claim.Body, claim.Data, checkpoint, ct);
            return result.Outcome switch
            {
                PushOutcome.Success => HandlerResult.Success(),
                PushOutcome.Permanent => HandlerResult.Permanent("Firebase rejected delivery input or sender identity."),
                _ => HandlerResult.Transient("Firebase delivery is temporarily unavailable.")
            };
        }
        if (channel != "email" || string.IsNullOrWhiteSpace(claim.Email)) return HandlerResult.Permanent("Email recipient is unavailable.");
        var username = config["Smtp:UserName"];
        var password = config["Smtp:Password"];
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
            return HandlerResult.Transient("SMTP credentials are unavailable.");
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(config["Smtp:FromName"] ?? "CareSitter", username));
        message.To.Add(MailboxAddress.Parse(claim.Email));
        message.Subject = claim.Title ?? "CareSitter";
        message.Body = new TextPart("plain") { Text = claim.Body ?? "" };
        using var smtp = new SmtpClient { Timeout = 10000 };
        await smtp.ConnectAsync("smtp.gmail.com", 587, SecureSocketOptions.StartTls, ct);
        await smtp.AuthenticateAsync(username, password, ct);
        await smtp.SendAsync(message, ct);
        await smtp.DisconnectAsync(true, ct);
        return HandlerResult.Success();
    }
}
