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
         (string.IsNullOrWhiteSpace(options.CustomerWebUrl) ||
          IsHttps(options.CustomerWebUrl) || IsLocalWeb(options.CustomerWebUrl)));

    // Flutter web can run on localhost during Development; deployment validation
    // separately requires an HTTPS public origin outside Development.
    private static bool IsLocalWeb(string value) =>
        Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttp && uri.IsLoopback &&
        string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Query) &&
        string.IsNullOrEmpty(uri.Fragment) && uri.AbsolutePath == "/";

    private static bool IsHttps(string value) => Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
        uri.Scheme == "https" && string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Fragment);
}
