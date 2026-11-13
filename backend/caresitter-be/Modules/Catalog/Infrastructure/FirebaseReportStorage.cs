using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Catalog.Infrastructure;

/// <summary>Server credentials never leave this adapter. Client writes are scoped to one immutable object.</summary>
public sealed class FirebaseReportStorage : IFirebaseReportStorage, IDisposable
{
    private readonly HttpClient _http;
    private readonly ILogger<FirebaseReportStorage> _logger;
    private readonly Lazy<GoogleCredential> _credential;
    private readonly Lazy<FirebaseApp> _app;
    public string Bucket { get; }
    public string ProjectId { get; }

    public FirebaseReportStorage(HttpClient http, IConfiguration config, ILogger<FirebaseReportStorage> logger)
    {
        _http = http;
        _logger = logger;
        // An explicit bucket avoids accidentally writing to a different Firebase project.
        Bucket = config["Firebase:StorageBucket"]?.Trim() ?? "";
        ProjectId = config["Firebase:ProjectId"]?.Trim() ?? "";
        _credential = new Lazy<GoogleCredential>(() =>
        {
            var json = config["Firebase:ServiceAccountJson"];
            var path = config["Firebase:ServiceAccountPath"] ?? config["GOOGLE_APPLICATION_CREDENTIALS"];
            return !string.IsNullOrWhiteSpace(json) ? GoogleCredential.FromJson(json)
                : !string.IsNullOrWhiteSpace(path) ? GoogleCredential.FromFile(path)
                : GoogleCredential.GetApplicationDefault();
        });
        _app = new Lazy<FirebaseApp>(() => FirebaseApp.Create(
            new AppOptions { Credential = _credential.Value, ProjectId = ProjectId },
            "CareSitterReports-" + Guid.NewGuid().ToString("N")));
    }

    public async Task<Result<string>> CreateTokenAsync(ReportUpload report, long expiresAtMs, CancellationToken ct)
    {
        if (!Matches(report)) return Unavailable();
        try
        {
            return await FirebaseAuth.GetAuth(_app.Value).CreateCustomTokenAsync(report.OwnerUserId.ToString("D"),
                new Dictionary<string, object> {
                    ["careReportPath"] = report.ObjectKey, ["careReportSize"] = report.SizeBytes,
                    ["careReportChecksum"] = report.Checksum, ["careSessionExpiresAtMs"] = expiresAtMs
                }, ct);
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            _logger.LogWarning("Report Firebase session unavailable ({ErrorType}).", ex.GetType().Name);
            return Unavailable();
        }
    }

    public async Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct)
    {
        if (!Matches(report)) return Unavailable();
        try
        {
            var token = await _credential.Value.CreateScoped("https://www.googleapis.com/auth/devstorage.read_only")
                .UnderlyingCredential.GetAccessTokenForRequestAsync(cancellationToken: ct);
            var path = $"https://storage.googleapis.com/storage/v1/b/{Uri.EscapeDataString(Bucket)}/o/{Uri.EscapeDataString(report.ObjectKey)}";
            using var metadataRequest = Request(path, token);
            using var metadataResponse = await _http.SendAsync(metadataRequest, HttpCompletionOption.ResponseHeadersRead, ct);
            if (metadataResponse.StatusCode == HttpStatusCode.NotFound) return Pending();
            if (!metadataResponse.IsSuccessStatusCode) return Unavailable();
            await using var metadataStream = await metadataResponse.Content.ReadAsStreamAsync(ct);
            using var metadata = await JsonDocument.ParseAsync(metadataStream, cancellationToken: ct);
            var root = metadata.RootElement;
            if (root.GetProperty("contentType").GetString() != "application/pdf" ||
                !long.TryParse(root.GetProperty("size").GetString(), out var size) || size != report.SizeBytes ||
                size is < 16 or > ReportPdfPolicy.MaxBytes)
                return Error.Validation("report.invalid_pdf", "Tệp Firebase không khớp PDF đã đăng ký.");
            var generation = root.GetProperty("generation").GetString()!;
            // Read the inspected generation, never an object replaced between metadata and content calls.
            using var contentRequest = Request(path + "?alt=media&generation=" + Uri.EscapeDataString(generation), token);
            using var content = await _http.SendAsync(contentRequest, HttpCompletionOption.ResponseHeadersRead, ct);
            if (content.StatusCode == HttpStatusCode.NotFound) return Pending();
            if (!content.IsSuccessStatusCode) return Unavailable();
            await using var stream = await content.Content.ReadAsStreamAsync(ct);
            using var buffer = new MemoryStream();
            var chunk = new byte[81920];
            int count;
            while ((count = await stream.ReadAsync(chunk, ct)) > 0)
            {
                if (buffer.Length + count > report.SizeBytes)
                    return Error.Validation("report.invalid_pdf", "Kích thước PDF không hợp lệ.");
                await buffer.WriteAsync(chunk.AsMemory(0, count), ct);
            }
            var bytes = buffer.ToArray();
            if (bytes.LongLength != report.SizeBytes || !ReportPdfPolicy.IsPdf(bytes) ||
                Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant() != report.Checksum)
                return Error.Validation("report.invalid_pdf", "Tệp Firebase không khớp PDF đã đăng ký.");
            return bytes;
        }
        catch (Exception ex) when (ex is not OperationCanceledException || !ct.IsCancellationRequested)
        {
            _logger.LogWarning("Report Firebase read unavailable ({ErrorType}).", ex.GetType().Name);
            return Unavailable();
        }
    }

    private bool Matches(ReportUpload report) => !string.IsNullOrWhiteSpace(ProjectId) &&
        !string.IsNullOrWhiteSpace(Bucket) && report.StorageProvider == "FIREBASE" && report.CloudName == Bucket &&
        report.ObjectKey == $"reports/{report.OwnerUserId:D}/{report.Id:N}.pdf";
    private static HttpRequestMessage Request(string url, string token) => new(HttpMethod.Get, url)
        { Headers = { Authorization = new AuthenticationHeaderValue("Bearer", token) } };
    private static Error Unavailable() => Error.Unavailable("report.firebase_unavailable",
        "Chưa kết nối được Firebase Storage. Kiểm tra cấu hình bucket và thử lại.");
    private static Error Pending() => Error.Conflict("report.upload_pending", "Firebase chưa có tệp hoàn chỉnh. Vui lòng thử lại cùng tệp.");
    public void Dispose() { if (_app.IsValueCreated) _app.Value.Delete(); }
}
