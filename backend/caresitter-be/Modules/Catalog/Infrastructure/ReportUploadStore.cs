using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Infrastructure;

public sealed class ReportUploadStore(CatalogDbContext db) : IReportUploadStore
{
    public async Task<Result<ReportUpload>> ReserveAsync(Guid owner, Guid booking, Guid key,
        string checksum, long bytes, string cloud, DateTimeOffset now, CancellationToken ct, string storageProvider = "CLOUDINARY")
    {
        // Serialize only the reservation. Never hold a DB lock during Cloudinary I/O.
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var scope = $"report:{owner:D}:{key:D}";
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({scope}, 0))", ct);
        var report = await db.ReportUploads.SingleOrDefaultAsync(x => x.OwnerUserId == owner && x.IdempotencyKey == key, ct);
        if (report is not null)
        {
            if (report.BookingId != booking || report.Checksum != checksum || report.SizeBytes != bytes ||
                report.CloudName != cloud || report.StorageProvider != storageProvider)
                return Error.Conflict("report.idempotency_conflict", "Khóa upload đã dùng cho tệp khác.");
            if (report.Status == "COMPLETED") return report;
            // Firebase objects are immutable. Retrying the same intent can safely reconcile immediately.
            if (storageProvider == "FIREBASE") return report;
            if (report.LeaseUntil > now)
                return Error.Conflict("report.upload_pending", "Upload đang được xử lý. Vui lòng kiểm tra lại sau 90 giây.");
            report.Claim(now);
        }
        else
        {
            report = ReportUpload.Create(owner, booking, key, checksum, bytes, cloud, now, storageProvider);
            db.ReportUploads.Add(report);
        }
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return report;
    }

    public async Task<bool> CompleteAsync(ReportUpload report, CancellationToken ct)
    {
        var lease = report.LeaseToken;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Fence a timed-out worker after a newer retry has claimed the operation.
        var updated = await db.ReportUploads.Where(x => x.Id == report.Id && x.LeaseToken == lease && x.Status == "PENDING")
            .ExecuteUpdateAsync(set => set.SetProperty(x => x.Status, "COMPLETED"), ct);
        if (updated != 1) return false;
        db.MediaAssets.Add(MediaAsset.CreateSecureReport(report.Id, report.OwnerUserId, report.BookingId,
            report.CloudName, report.ObjectKey, report.SizeBytes, report.Checksum, report.StorageProvider));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        report.Complete();
        return true;
    }
    public Task<ReportUpload?> FindAsync(Guid id, CancellationToken ct) =>
        db.ReportUploads.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
    public async Task<IReadOnlyList<ReportUpload>> ListAsync(Guid owner, Guid booking, int page, int pageSize, CancellationToken ct) =>
        await db.ReportUploads.AsNoTracking().Where(x => x.OwnerUserId == owner && x.BookingId == booking)
            .OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id).Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
}
