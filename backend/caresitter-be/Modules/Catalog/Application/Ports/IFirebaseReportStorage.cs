using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public interface IFirebaseReportStorage
{
    string Bucket { get; }
    string ProjectId { get; }
    Task<Result<string>> CreateTokenAsync(ReportUpload report, long expiresAtMs, CancellationToken ct);
    Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct);
}
