using FirebaseAdmin;
using Google.Api.Gax;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;
using Microsoft.Extensions.Options;

namespace CareSitter.ApiHost.ChatFirestore;

public sealed class ChatFirestoreClient
{
    private readonly Lazy<FirestoreDb> _database;
    private readonly Lazy<FirebaseApp> _authApp;

    public ChatFirestoreClient(IOptions<ChatFirestoreOptions> options, IConfiguration configuration)
    {
        var settings = options.Value;
        var credential = new Lazy<GoogleCredential>(() =>
        {
            var json = configuration["Firebase:ServiceAccountJson"];
            var path = configuration["Firebase:ServiceAccountPath"]
                ?? configuration["GOOGLE_APPLICATION_CREDENTIALS"];
            return !string.IsNullOrWhiteSpace(json)
                ? CredentialFactory.FromJson<ServiceAccountCredential>(json).ToGoogleCredential()
                : !string.IsNullOrWhiteSpace(path)
                    ? CredentialFactory.FromFile<ServiceAccountCredential>(path).ToGoogleCredential()
                    : GoogleCredential.GetApplicationDefault();
        });
        _database = new Lazy<FirestoreDb>(() =>
        {
            var builder = new FirestoreDbBuilder
            {
                ProjectId = settings.ProjectId,
                EmulatorDetection = settings.UseEmulator
                    ? EmulatorDetection.EmulatorOnly : EmulatorDetection.None
            };
            if (!settings.UseEmulator) builder.GoogleCredential = credential.Value;
            return builder.Build();
        });
        _authApp = new Lazy<FirebaseApp>(() => FirebaseApp.Create(
            new AppOptions { Credential = credential.Value }, "CareSitterChatFirestore"));
    }

    public FirestoreDb Database => _database.Value;
    public FirebaseApp AuthApp => _authApp.Value;
}
