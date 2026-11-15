namespace CareSitter.Modules.Identity.Infrastructure;

public sealed class RecoveryOptions
{
    public bool Enabled { get; set; }
    public string SecretKey { get; set; } = string.Empty;
    public int CodeMinutes { get; set; } = 10;
    public int GrantMinutes { get; set; } = 5;
    public int ResendSeconds { get; set; } = 60;
    public int RequestsPerHour { get; set; } = 5;
    public int MaxAttempts { get; set; } = 5;
    public int MetadataRetentionDays { get; set; } = 7;
}
