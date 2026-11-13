using CareSitter.Infrastructure.Media;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Options;
using System.Security.Cryptography;

namespace CareSitter.IntegrationTests;

public sealed class ReportCloudinarySmokeTests
{
    [ProviderFact]
    [Trait("Category", "CloudinaryLive")]
    public async Task Real_authenticated_raw_pdf_roundtrips_without_public_access()
    {
        var settings = new CloudinarySettings {
            CloudName = Environment.GetEnvironmentVariable("LAB3_CLOUDINARY_CLOUD")!,
            ApiKey = Environment.GetEnvironmentVariable("LAB3_CLOUDINARY_KEY")!,
            ApiSecret = Environment.GetEnvironmentVariable("LAB3_CLOUDINARY_SECRET")! };
        var bytes = await File.ReadAllBytesAsync(Environment.GetEnvironmentVariable("LAB3_REPORT_PDF")!);
        Assert.True(ReportPdfPolicy.IsPdf(bytes));
        var report = ReportUpload.Create(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant(), bytes.Length,
            settings.CloudName, DateTimeOffset.UtcNow);
        using var http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false });
        var gateway = new CloudinaryReportDocumentGateway(http, Options.Create(settings), new KycMediaSecurityTests.Clock { Now = DateTimeOffset.UtcNow });
        var cloudinary = new Cloudinary(new Account(settings.CloudName, settings.ApiKey, settings.ApiSecret));
        cloudinary.Api.Secure = true;
        try
        {
            var uploaded = await gateway.UploadAsync(report, bytes, default);
            Assert.True(uploaded.IsSuccess, uploaded.Error.Code);
            var downloaded = await gateway.DownloadAsync(report, default);
            Assert.True(downloaded.IsSuccess, downloaded.Error.Code);
            Assert.Equal(bytes, downloaded.Value);
            using var privateCdn = await http.GetAsync($"https://res.cloudinary.com/{settings.CloudName}/raw/authenticated/{report.ObjectKey}");
            Assert.False(privateCdn.IsSuccessStatusCode);
            using var publicCdn = await http.GetAsync($"https://res.cloudinary.com/{settings.CloudName}/raw/upload/{report.ObjectKey}");
            Assert.False(publicCdn.IsSuccessStatusCode);
        }
        finally
        {
            var deleted = await cloudinary.DestroyAsync(new DeletionParams(report.ObjectKey) {
                ResourceType = ResourceType.Raw, Type = "authenticated", Invalidate = true });
            Assert.True(deleted.Result is "ok" or "not found", "Temporary provider fixture cleanup failed.");
        }
    }
}

internal sealed class ProviderFactAttribute : FactAttribute
{
    public ProviderFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("LAB3_PROVIDER_SMOKE") != "1")
            Skip = "Opt-in Cloudinary smoke requires synthetic PDF and server-only credentials.";
    }
}
