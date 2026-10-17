namespace CareSitter.Modules.Payments.Application;

public sealed class PayOSPayoutOptions
{
    public const string SectionName = "Payments:PayOS:Payout";

    public bool Enabled { get; set; }
    public string ClientId { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ChecksumKey { get; set; } = "";
    public int PollIntervalSeconds { get; set; } = 5;
    public int QueryDelaySeconds { get; set; } = 15;
    public int BatchSize { get; set; } = 10;

    public bool HasCredentials =>
        !string.IsNullOrWhiteSpace(ClientId) &&
        !string.IsNullOrWhiteSpace(ApiKey) &&
        ChecksumKey.Length >= 32;

    public static bool IsValid(PayOSPayoutOptions options) =>
        (!options.Enabled || options.HasCredentials) &&
        options.PollIntervalSeconds is >= 1 and <= 300 &&
        options.QueryDelaySeconds is >= 5 and <= 3600 &&
        options.BatchSize is >= 1 and <= 100;
}
