namespace CareSitter.ApiHost.ChatFirestore;

public sealed class ChatFirestoreOptions
{
    public bool ProjectionEnabled { get; set; }
    public bool ClientReadEnabled { get; set; }
    public bool UseEmulator { get; set; }
    public string ProjectId { get; set; } = string.Empty;
    public int PollSeconds { get; set; } = 3;
    public int BatchSize { get; set; } = 50;
    public int MaxAttempts { get; set; } = 8;
    public bool ReconcileEnabled { get; set; } = true;
    public int ReconcileBatchSize { get; set; } = 100;
}
