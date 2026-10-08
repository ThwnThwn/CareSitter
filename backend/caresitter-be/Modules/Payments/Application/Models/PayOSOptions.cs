namespace CareSitter.Modules.Payments.Application;

public sealed class PayOSOptions
{
    public const string SectionName = "Payments:PayOS";
    public bool Enabled { get; set; }
    public string ClientId { get; set; } = "";
    public string ApiKey { get; set; } = "";
    public string ChecksumKey { get; set; } = "";
    public string ReturnUrl { get; set; } = "";
    public string CancelUrl { get; set; } = "";
    public string CustomerWebUrl { get; set; } = "";
    public bool HasCredentials => !string.IsNullOrWhiteSpace(ClientId) &&
        !string.IsNullOrWhiteSpace(ApiKey) && ChecksumKey.Length >= 32;

    public static bool IsValid(PayOSOptions options) => !options.Enabled ||
        (options.HasCredentials &&
         IsHttps(options.ReturnUrl) && IsHttps(options.CancelUrl) &&
         (string.IsNullOrWhiteSpace(options.CustomerWebUrl) || IsHttps(options.CustomerWebUrl)));

    private static bool IsHttps(string value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme == "https" && string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Fragment);
}
