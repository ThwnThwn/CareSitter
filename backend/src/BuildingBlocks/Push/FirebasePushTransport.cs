using CareSitter.Contracts.Services;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;

namespace CareSitter.Push;

public enum PushOutcome { Success, Transient, Permanent }
public sealed record PushResult(PushOutcome Outcome, IReadOnlyList<string> UnregisteredTokens);

public sealed class FirebasePushTransport(IConfiguration config)
{
    private static readonly object Gate = new();

    public async Task<PushResult> SendAsync(IEnumerable<string> tokens, string? title, string? body,
        IReadOnlyDictionary<string, string>? data, Func<string[], CancellationToken, Task> checkpoint, CancellationToken ct)
    {
        var stale = new List<string>();
        var transient = false;
        var permanent = false;
        foreach (var batch in tokens.Distinct(StringComparer.Ordinal).Chunk(500))
        {
            var app = GetApp();
            if (app is null) return new(PushOutcome.Transient, stale);
            var result = await FirebaseMessaging.GetMessaging(app).SendEachForMulticastAsync(new MulticastMessage
            {
                Tokens = batch, Data = data, Notification = new Notification { Title = title, Body = body }
            }, ct);
            var completed = new List<string>();
            for (var i = 0; i < batch.Length; i++)
            {
                var response = result.Responses[i];
                if (response.IsSuccess || response.Exception?.MessagingErrorCode == MessagingErrorCode.Unregistered)
                {
                    completed.Add(PushTargetKey.FromToken(batch[i]));
                    if (!response.IsSuccess) stale.Add(batch[i]);
                }
                else if (response.Exception?.MessagingErrorCode is MessagingErrorCode.InvalidArgument or MessagingErrorCode.SenderIdMismatch)
                    permanent = true;
                else
                    transient = true;
            }
            if (completed.Count > 0) await checkpoint(completed.ToArray(), ct);
        }
        return new(transient ? PushOutcome.Transient : permanent ? PushOutcome.Permanent : PushOutcome.Success, stale);
    }

    private FirebaseApp? GetApp()
    {
        lock (Gate)
        {
            if (FirebaseApp.DefaultInstance is { } existing) return existing;
            var json = config["Firebase:ServiceAccountJson"];
            var path = config["Firebase:ServiceAccountPath"];
            if (string.IsNullOrWhiteSpace(path)) path = config["GOOGLE_APPLICATION_CREDENTIALS"];
            GoogleCredential? credential = null;
            if (!string.IsNullOrWhiteSpace(json)) credential = GoogleCredential.FromJson(json);
            else if (!string.IsNullOrWhiteSpace(path) && File.Exists(path)) credential = GoogleCredential.FromFile(path);
            else if (config.GetValue<bool>("Firebase:UseApplicationDefaultCredentials")) credential = GoogleCredential.GetApplicationDefault();
            return credential is null ? null : FirebaseApp.Create(new AppOptions { Credential = credential });
        }
    }
}
