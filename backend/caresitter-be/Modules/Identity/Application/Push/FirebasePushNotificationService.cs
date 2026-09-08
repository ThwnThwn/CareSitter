using CareSitter.Contracts.Services;
using CareSitter.Modules.Identity.Infrastructure;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Identity.Application.Push;

internal sealed class FirebasePushNotificationService(
    IdentityDbContext db,
    IConfiguration configuration,
    ILogger<FirebasePushNotificationService> logger) : IPushNotificationService
{
    private static readonly object AppLock = new();

    public async Task SendToUserAsync(UserNotificationMessage message, CancellationToken ct = default)
    {
        var app = GetOrCreateFirebaseApp();
        if (app is null)
        {
            logger.LogDebug("Firebase is not configured; skipping push notification for user {UserId}.",
                message.UserId);
            return;
        }

        var tokens = await db.UserDevices.AsNoTracking()
            .Where(x => x.UserId == message.UserId && x.PushToken != null)
            .Select(x => x.PushToken!)
            .Distinct()
            .ToListAsync(ct);

        if (tokens.Count == 0)
            return;

        var data = new Dictionary<string, string>(message.Data ?? new Dictionary<string, string>())
        {
            ["type"] = message.Type
        };

        var multicast = new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification
            {
                Title = message.Title,
                Body = message.Body
            },
            Data = data
        };

        try
        {
            var response = await FirebaseMessaging.GetMessaging(app)
                .SendEachForMulticastAsync(multicast, ct);

            if (response.FailureCount > 0)
            {
                logger.LogWarning("Firebase push sent to user {UserId} with {FailureCount}/{TotalCount} failures.",
                    message.UserId, response.FailureCount, tokens.Count);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Firebase push failed for user {UserId}.", message.UserId);
        }
    }

    private FirebaseApp? GetOrCreateFirebaseApp()
    {
        if (FirebaseApp.DefaultInstance is { } existing)
            return existing;

        lock (AppLock)
        {
            if (FirebaseApp.DefaultInstance is { } current)
                return current;

            var json = configuration["Firebase:ServiceAccountJson"];
            if (!string.IsNullOrWhiteSpace(json))
            {
                return FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromJson(json)
                });
            }

            var path = configuration["Firebase:ServiceAccountPath"]
                ?? configuration["GOOGLE_APPLICATION_CREDENTIALS"];
            if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
            {
                return FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(path)
                });
            }

            if (configuration.GetValue<bool>("Firebase:UseApplicationDefaultCredentials"))
            {
                return FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.GetApplicationDefault()
                });
            }
        }

        return null;
    }
}
