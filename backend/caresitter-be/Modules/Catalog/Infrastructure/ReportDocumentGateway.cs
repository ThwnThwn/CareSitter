using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Infrastructure;

/// <summary>Legacy reports retain their original private provider; new Firebase reports remain readable through the API.</summary>
public sealed class ReportDocumentGateway(CloudinaryReportDocumentGateway legacy, IFirebaseReportStorage firebase)
    : IReportDocumentGateway
{
    public string CloudName => legacy.CloudName;
    public Task<Result<bool>> UploadAsync(ReportUpload report, byte[] bytes, CancellationToken ct) =>
        legacy.UploadAsync(report, bytes, ct);
    public Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct) =>
        report.StorageProvider == "FIREBASE" ? firebase.DownloadAsync(report, ct) : legacy.DownloadAsync(report, ct);
}
