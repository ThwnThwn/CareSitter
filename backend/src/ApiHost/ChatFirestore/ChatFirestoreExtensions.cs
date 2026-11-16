namespace CareSitter.ApiHost.ChatFirestore;

internal static class ChatFirestoreExtensions
{
    public static void AddChatFirestore(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<ChatFirestoreOptions>()
            .Bind(configuration.GetSection("ChatFirestore"))
            .Validate(options => !options.ClientReadEnabled || options.ProjectionEnabled,
                "ChatFirestore client reads require projection to be enabled.")
            .Validate(options => !options.ProjectionEnabled ||
                (!string.IsNullOrWhiteSpace(options.ProjectId) &&
                 (!options.UseEmulator ||
                  !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("FIRESTORE_EMULATOR_HOST")))),
                "ChatFirestore requires a project ID and an emulator host when using the emulator.")
            .ValidateOnStart();
        services.AddSingleton<ChatFirestoreClient>();
        services.AddSingleton<ChatFirestoreDocuments>();
        services.AddSingleton<ChatFirestoreProjector>();
        services.AddHostedService<ChatFirestoreProjectionWorker>();
        services.AddScoped<ChatFirestoreReconciler>();
        services.AddScoped<ChatFirestoreReconcileJob>();
        services.AddScoped<ChatFirestoreAccessGate>();
    }
}
