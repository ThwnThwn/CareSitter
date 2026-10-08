using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts.Notifications;
using CareSitter.NotificationWorker.Application.Ports;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;

namespace CareSitter.NotificationWorker.Infrastructure.Delivery;

/// <summary>Push/email adapters with explicit failure reporting and no database access.</summary>
public sealed class NotificationSender(IConfiguration config) : INotificationSender
{
    private static readonly object FirebaseLock = new();

    /// <summary>Delivers bounded provider requests. Provider acceptance is not an exactly-once receipt.</summary>
    public async Task<HandlerResult> SendAsync(string channel, DeliveryClaim claim, CancellationToken ct)
    {
        if (channel == "push")
        {
            var tokens = claim.PushTokens ?? [];
            if (tokens.Length == 0) return HandlerResult.Success();
            var path = config["Firebase:ServiceAccountPath"] ?? config["GOOGLE_APPLICATION_CREDENTIALS"];
            if (string.IsNullOrWhiteSpace(path) || !File.Exists(path))
                return HandlerResult.Transient("Firebase credentials are unavailable.");
            FirebaseApp app;
            lock (FirebaseLock)
                app = FirebaseApp.DefaultInstance ?? FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.FromFile(path) });
            foreach (var batch in tokens.Chunk(500))
            {
                var response = await FirebaseMessaging.GetMessaging(app).SendEachForMulticastAsync(new MulticastMessage
                {
                    Tokens = batch, Data = claim.Data,
                    Notification = new Notification { Title = claim.Title, Body = claim.Body }
                }, ct);
                // An expired token is harmless; rejected payloads or sender identities need operator review.
                if (response.Responses.Any(x => !x.IsSuccess && x.Exception?.MessagingErrorCode is
                    (MessagingErrorCode.InvalidArgument or MessagingErrorCode.SenderIdMismatch)))
                    return HandlerResult.Permanent("Firebase rejected the delivery input or sender identity.");
                if (response.Responses.Any(x => !x.IsSuccess && x.Exception?.MessagingErrorCode is not MessagingErrorCode.Unregistered))
                    return HandlerResult.Transient("Firebase returned a transient delivery failure.");
            }
            return HandlerResult.Success();
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
