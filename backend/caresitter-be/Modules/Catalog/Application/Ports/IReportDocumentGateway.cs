using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public interface IReportDocumentGateway
{
    string CloudName { get; }
    Task<Result<bool>> UploadAsync(ReportUpload report, byte[] bytes, CancellationToken ct);
    Task<Result<byte[]>> DownloadAsync(ReportUpload report, CancellationToken ct);
}
