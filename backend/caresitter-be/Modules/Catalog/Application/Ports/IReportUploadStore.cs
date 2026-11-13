using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public interface IReportUploadStore
{
    Task<Result<ReportUpload>> ReserveAsync(Guid owner, Guid booking, Guid key, string checksum,
        long bytes, string cloud, DateTimeOffset now, CancellationToken ct, string storageProvider = "CLOUDINARY");
    Task<bool> CompleteAsync(ReportUpload report, CancellationToken ct);
    Task<ReportUpload?> FindAsync(Guid id, CancellationToken ct);
    Task<IReadOnlyList<ReportUpload>> ListAsync(Guid owner, Guid booking, int page, int pageSize, CancellationToken ct);
}
