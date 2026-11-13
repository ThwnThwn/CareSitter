using System.Security.Cryptography;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ReportResponse(Guid Id, Guid BookingId, string Status, long SizeBytes, DateTimeOffset CreatedAt);

public sealed class ReportService(IReportUploadStore store, IReportDocumentGateway documents,
    IBookingReportAccess bookings, ICurrentUser user, IClock clock)
{
    public static ReportResponse Response(ReportUpload report) => new(report.Id, report.BookingId,
        report.Status, report.SizeBytes, report.CreatedAt);

    public async Task<Result<ReportResponse>> UploadAsync(Guid bookingId, Guid key, byte[] bytes, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("auth.required", "Cần đăng nhập.");
        if (!user.IsInRole("CUSTOMER") || !await bookings.IsCustomerAsync(bookingId, owner, ct))
            return Error.NotFound("report.booking_not_found", "Không tìm thấy lịch hẹn của bạn.");
        if (key == Guid.Empty || !ReportPdfPolicy.IsPdf(bytes))
            return Error.Validation("report.invalid_pdf", "Cần tệp PDF hợp lệ, tối đa 10 MB và khóa upload hợp lệ.");
        if (string.IsNullOrWhiteSpace(documents.CloudName))
            return Error.Unavailable("report.provider_unavailable", "Chưa cấu hình nơi lưu báo cáo.");
        var checksum = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        var reserved = await store.ReserveAsync(owner, bookingId, key, checksum,
            bytes.LongLength, documents.CloudName, clock.UtcNow, ct);
        if (reserved.IsFailure) return reserved.Error;
        var report = reserved.Value;
        if (report.Status == "COMPLETED") return Response(report);
        var uploaded = await documents.UploadAsync(report, bytes, ct);
        if (uploaded.IsFailure) return uploaded.Error;
        if (!await store.CompleteAsync(report, ct))
            return Error.Conflict("report.upload_pending", "Đang đối soát upload. Vui lòng kiểm tra lại sau.");
        return Response(report);
    }

    public async Task<Result<IReadOnlyList<ReportResponse>>> ListAsync(Guid booking, int page, int pageSize, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("auth.required", "Cần đăng nhập.");
        if (page < 1 || page > 10000 || pageSize is < 1 or > 50)
            return Error.Validation("report.pagination", "Phân trang không hợp lệ.");
        if (!await bookings.IsCustomerAsync(booking, owner, ct))
            return Error.NotFound("report.booking_not_found", "Không tìm thấy lịch hẹn của bạn.");
        var reports = await store.ListAsync(owner, booking, page, pageSize, ct);
        return reports.Select(Response).ToArray();
    }

    public async Task<Result<byte[]>> ReadAsync(Guid id, CancellationToken ct)
    {
        if (user.UserId is not { } owner) return Error.Unauthorized("auth.required", "Cần đăng nhập.");
        var report = await store.FindAsync(id, ct);
        if (report is null || report.Status != "COMPLETED" ||
            (report.OwnerUserId != owner && !user.IsInRole("ADMIN")))
            return Error.NotFound("report.not_found", "Không tìm thấy báo cáo.");
        return await documents.DownloadAsync(report, ct);
    }
}
