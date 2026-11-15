using System.Security.Cryptography;
using System.Text.RegularExpressions;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record PrepareFirebaseReport(Guid IdempotencyKey, long SizeBytes, string Checksum);
public sealed record FirebaseReportSession(ReportResponse Report, string Uid, string ProjectId,
    string Bucket, string ObjectPath, string? CustomToken, long ExpiresAtMs);

public sealed class FirebaseReportService(IReportUploadStore store, IFirebaseReportStorage storage,
    IBookingReportAccess bookings, ICurrentUser user, IClock clock)
{
    public async Task<Result<FirebaseReportSession>> PrepareAsync(Guid booking, PrepareFirebaseReport request,
        long accessExpiresAtMs, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("auth.required", "Cần đăng nhập.");
        if (!user.IsInRole("CUSTOMER") || !await bookings.IsCustomerAsync(booking, owner, ct))
            return Error.NotFound("report.booking_not_found", "Không tìm thấy lịch hẹn của bạn.");
        if (request.IdempotencyKey == Guid.Empty || request.SizeBytes is < 16 or > ReportPdfPolicy.MaxBytes ||
            request.Checksum is null || !Regex.IsMatch(request.Checksum, "\\A[a-f0-9]{64}\\z"))
            return Error.Validation("report.invalid_pdf", "Cần PDF tối đa 10 MB, SHA-256 và khóa upload hợp lệ.");
        if (string.IsNullOrWhiteSpace(storage.Bucket) || string.IsNullOrWhiteSpace(storage.ProjectId))
            return Error.Unavailable("report.firebase_unavailable", "Firebase Storage chưa được cấu hình.");
        var expires = Math.Min(accessExpiresAtMs, clock.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds());
        if (expires <= clock.UtcNow.ToUnixTimeMilliseconds())
            return Error.Unauthorized("auth.required", "Phiên đăng nhập đã hết hạn.");
        var reserved = await store.ReserveAsync(owner, booking, request.IdempotencyKey, request.Checksum,
            request.SizeBytes, storage.Bucket, clock.UtcNow, ct, "FIREBASE");
        if (reserved.IsFailure) return reserved.Error;
        var report = reserved.Value;
        string? token = null;
        if (report.Status != "COMPLETED")
        {
            var issued = await storage.CreateTokenAsync(report, expires, ct);
            if (issued.IsFailure) return issued.Error;
            token = issued.Value;
        }
        return new FirebaseReportSession(ReportService.Response(report), owner.ToString("D"),
            storage.ProjectId, storage.Bucket, report.ObjectKey, token, expires);
    }

    public async Task<Result<ReportResponse>> CompleteAsync(Guid id, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("auth.required", "Cần đăng nhập.");
        var report = await store.FindAsync(id, ct);
        if (report is null || report.OwnerUserId != owner || report.StorageProvider != "FIREBASE" ||
            !user.IsInRole("CUSTOMER") || !await bookings.IsCustomerAsync(report.BookingId, owner, ct))
            return Error.NotFound("report.not_found", "Không tìm thấy báo cáo.");
        if (report.Status == "COMPLETED") return ReportService.Response(report);
        var downloaded = await storage.DownloadAsync(report, ct);
        if (downloaded.IsFailure) return downloaded.Error;
        var bytes = downloaded.Value;
        if (bytes.LongLength != report.SizeBytes || !ReportPdfPolicy.IsPdf(bytes) ||
            Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant() != report.Checksum)
            return Error.Validation("report.invalid_pdf", "Tệp lưu trữ không khớp PDF đã đăng ký. Hãy tạo báo cáo mới.");
        if (!await store.CompleteAsync(report, ct))
        {
            var current = await store.FindAsync(id, ct);
            if (current?.Status == "COMPLETED") return ReportService.Response(current);
            return Error.Conflict("report.upload_pending", "Chưa xác nhận được kết quả. Vui lòng thử lại cùng tệp.");
        }
        return ReportService.Response(report);
    }
}
