namespace CareSitter.ApiHost.Nutrition;

public sealed class NutritionGatewayOptions
{
    public bool Enabled { get; set; }
    public string GrpcUrl { get; set; } = "";
    public string ServiceKey { get; set; } = "";
    public string? TrustedRootCertificatePath { get; set; }
    public int TimeoutSeconds { get; set; } = 15;
    public int KnowledgeTimeoutSeconds { get; set; } = 40;

    internal bool IsValid(bool development) => !Enabled ||
        (Uri.TryCreate(GrpcUrl, UriKind.Absolute, out var uri) && uri.AbsolutePath == "/" &&
         string.IsNullOrEmpty(uri.UserInfo) && string.IsNullOrEmpty(uri.Query) && string.IsNullOrEmpty(uri.Fragment) &&
         (uri.Scheme == "https" || development && uri.Scheme == "http") &&
         ServiceKey.Length is >= 32 and <= 256 && TimeoutSeconds is >= 1 and <= 30 &&
         KnowledgeTimeoutSeconds is >= 1 and <= 60);
}
