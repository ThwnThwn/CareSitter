using System.Security.Cryptography;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Media;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Options;
using Error = CareSitter.SharedKernel.Results.Error;

namespace CareSitter.Modules.Catalog.Infrastructure;

public sealed class CloudinaryReportDocumentGateway(HttpClient http, IOptions<CloudinarySettings> options,
    IClock clock) : IReportDocumentGateway
{
    public string CloudName => options.Value.CloudName;
    private Cloudinary Client()
    {
        var settings = options.Value;
        var client = new Cloudinary(new Account(settings.CloudName, settings.ApiKey, settings.ApiSecret));
        client.Api.Secure = true;
        return client;
    }
    public static RawUploadParams Parameters(Stream stream, string objectKey) => new()
    {
        File = new FileDescription("report.pdf", stream), PublicId = objectKey,
        Type = "authenticated", Overwrite = true, UseFilename = false, UniqueFilename = false
    };
    private bool Valid(ReportUpload report) => report.CloudName == CloudName &&
        report.ObjectKey == $"CareSitter/Reports/{report.OwnerUserId:D}/{report.Id:N}.pdf";

    public async Task<Result<bool>> UploadAsync(ReportUpload report, byte[] bytes, CancellationToken ct)
    {
        if (!Valid(report)) return Unavailable();
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
            deadline.CancelAfter(TimeSpan.FromSeconds(45));
            using var stream = new MemoryStream(bytes, false);
            // Immutable owner+checksum reservation makes overwrite safe after an unknown response.
            var uploaded = await Client().UploadAsync(Parameters(stream, report.ObjectKey), "raw", deadline.Token);
            return uploaded.Error is null && uploaded.PublicId == report.ObjectKey &&
                uploaded.Type == "authenticated" && uploaded.ResourceType == "raw" && uploaded.Bytes == bytes.LongLength
                ? true : Unavailable();
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { return Unavailable(); }
    }
    public async Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct)
    {
        if (!Valid(report)) return Unavailable();
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
            deadline.CancelAfter(TimeSpan.FromSeconds(30));
            // Provider URL stays on the server. JWT authorization is checked on every read.
            var url = new Uri(Client().DownloadPrivate(report.ObjectKey, format: "", type: "authenticated",
                expiresAt: clock.UtcNow.AddSeconds(30).ToUnixTimeSeconds(), resourceType: "raw"));
            if (url.Scheme != "https" || url.Host != "api.cloudinary.com" || !url.IsDefaultPort) return Unavailable();
            using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
            if (!response.IsSuccessStatusCode || response.Content.Headers.ContentLength > ReportPdfPolicy.MaxBytes) return Unavailable();
            await using var stream = await response.Content.ReadAsStreamAsync(deadline.Token);
            using var buffer = new MemoryStream();
            var chunk = new byte[8192]; int count;
            while ((count = await stream.ReadAsync(chunk, deadline.Token)) > 0)
            {
                if (buffer.Length + count > ReportPdfPolicy.MaxBytes) return Unavailable();
                buffer.Write(chunk, 0, count);
            }
            var bytes = buffer.ToArray();
            if (!ReportPdfPolicy.IsPdf(bytes) || bytes.LongLength != report.SizeBytes ||
                Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant() != report.Checksum) return Unavailable();
            return bytes;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch { return Unavailable(); }
    }
    private static Error Unavailable() => Error.Unavailable("report.provider_unavailable", "Chưa thể lưu hoặc đọc báo cáo. Vui lòng thử lại sau.");
}

