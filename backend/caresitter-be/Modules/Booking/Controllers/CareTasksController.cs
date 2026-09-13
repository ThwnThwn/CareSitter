using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Booking.Controllers;

/// <summary>
/// Quản lý danh sách nhiệm vụ chăm sóc (care tasks) trong một booking.
/// Caregiver thực hiện hoàn thành hoặc bỏ qua từng task, mỗi thao tác được ghi vào timeline.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/bookings/{id:guid}/tasks")]
public sealed class CareTasksController(
    BookingDbContext db,
    CatalogDbContext catalogDb,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMediaService mediaService) : ControllerBase
{
    /// <summary>Lấy toàn bộ task của booking, sắp xếp theo SortOrder.</summary>
    [HttpGet]
    public async Task<IActionResult> List(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        var canRead = booking.CustomerId == userId;
        if (!canRead && booking.CaregiverId is { } caregiverId)
            canRead = await people.IsCaregiverForBookingAsync(caregiverId, userId, ct);
        if (!canRead) return Forbid();

        var tasks = await db.CareTasks.AsNoTracking()
            .Where(x => x.BookingId == id)
            .OrderBy(x => x.SortOrder)
            .ToListAsync(ct);

        if (tasks.Count == 0)
        {
            var serviceCode = await catalogDb.ServiceTypes.AsNoTracking()
                .Where(x => x.Id == booking.ServiceTypeId)
                .Select(x => x.Code)
                .SingleOrDefaultAsync(ct);
            var defaults = DefaultTasksFor(serviceCode);
            if (defaults.Count > 0)
            {
                db.CareTasks.AddRange(defaults.Select((item, index) =>
                    CareTask.Create(id, item.Name, item.Description, item.IsRequired,
                        item.RequiresPhoto, index + 1)));
                await db.SaveChangesAsync(ct);
                tasks = await db.CareTasks.AsNoTracking()
                    .Where(x => x.BookingId == id)
                    .OrderBy(x => x.SortOrder)
                    .ToListAsync(ct);
            }
        }

        var taskIds = tasks.Select(t => t.Id).ToArray();
        var photoEvents = await db.TimelineEvents.AsNoTracking()
            .Where(x => x.BookingId == id && x.EventType == "PHOTO_UPLOADED" &&
                        x.TaskId.HasValue && taskIds.Contains(x.TaskId.Value) && x.MediaId.HasValue)
            .Select(x => new { x.TaskId, x.MediaId })
            .ToListAsync(ct);
        var mediaIds = photoEvents.Select(x => x.MediaId!.Value).Distinct().ToArray();
        var mediaUrls = await catalogDb.MediaAssets.AsNoTracking()
            .Where(x => mediaIds.Contains(x.Id) && x.Url != null)
            .ToDictionaryAsync(x => x.Id, x => x.Url!, ct);

        return Ok(tasks.Select(t => new CareTaskResponse(
            t.Id, t.BookingId, t.Name, t.Description, t.IsRequired,
            t.RequiresPhoto, t.SortOrder, t.Status, t.CompletedAt,
            photoEvents.Where(x => x.TaskId == t.Id && x.MediaId.HasValue)
                .Select(x => mediaUrls.GetValueOrDefault(x.MediaId!.Value))
                .Where(x => x != null).Cast<string>().ToArray())));
    }

    /// <summary>Tạo task mới cho booking (chỉ customer/admin). Tác vụ có thể bắt buộc hoặc tùy chọn.</summary>
    [HttpPost]
    public async Task<IActionResult> Create(Guid id, [FromBody] CreateCareTaskRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.SingleOrDefaultAsync(x => x.Id == id && x.CustomerId == userId, ct);
        if (booking is null) return NotFound();

        var task = CareTask.Create(id, request.Name, request.Description,
            request.IsRequired, request.RequiresPhoto, request.SortOrder);
        db.CareTasks.Add(task);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/bookings/{id}/tasks/{task.Id}",
            new CareTaskResponse(task.Id, task.BookingId, task.Name, task.Description,
                task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt,
                Array.Empty<string>()));
    }

    /// <summary>Caregiver đánh dấu task đã hoàn thành và ghi sự kiện TASK_DONE vào timeline.</summary>
    [HttpPut("{taskId:guid}/complete")]
    public async Task<IActionResult> CompleteTask(Guid id, Guid taskId, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return Forbid();

        var task = await db.CareTasks.SingleOrDefaultAsync(x => x.Id == taskId && x.BookingId == id, ct);
        if (task is null) return NotFound();

        if (task.RequiresPhoto && !await db.TimelineEvents.AnyAsync(
                x => x.BookingId == id && x.TaskId == taskId && x.EventType == "PHOTO_UPLOADED", ct))
            return BadRequest(new { error = "Nhiem vu nay can co anh minh chung truoc khi hoan thanh." });

        task.MarkDone();
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            id, caregiverId, "TASK_DONE", $"Hoan thanh: {task.Name}", taskId: taskId));

        await db.SaveChangesAsync(ct);
        return Ok(new CareTaskResponse(task.Id, task.BookingId, task.Name, task.Description,
            task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt,
            await GetPhotoUrls(task.BookingId, task.Id, ct)));
    }

    /// <summary>Upload ảnh minh chứng cho một task của caregiver được assign.</summary>
    [HttpPost("{taskId:guid}/photos")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadPhoto(Guid id, Guid taskId, IFormFile file, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (file is null || file.Length == 0) return BadRequest(new { error = "Vui long chon mot anh." });
        if (file.Length > 10 * 1024 * 1024) return BadRequest(new { error = "Anh khong duoc vuot qua 10 MB." });

        var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
        if (!allowedTypes.Contains(file.ContentType, StringComparer.OrdinalIgnoreCase))
            return BadRequest(new { error = "Chi chap nhan anh JPG, PNG hoac WEBP." });

        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)) return Forbid();

        var task = await db.CareTasks.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == taskId && x.BookingId == id, ct);
        if (task is null) return NotFound();

        await using var stream = file.OpenReadStream();
        // Lưu ảnh minh chứng vào thư mục Cloudinary: CareSitter/Checklist
        var upload = await mediaService.UploadImageAsync(
            stream,
            file.FileName,
            "CareSitter/Checklist",
            ct);
        if (upload.IsFailure) return BadRequest(new { error = upload.Error.Message });

        var assetResult = MediaAsset.Create(
            storageProvider: "CLOUDINARY",
            bucket: "caresitter",
            objectKey: upload.Value,
            mediaType: "PHOTO",
            ownerUserId: userId,
            bookingId: id,
            url: upload.Value,
            mimeType: file.ContentType,
            sizeBytes: file.Length);
        if (assetResult.IsFailure) return BadRequest(new { error = assetResult.Error.Message });

        catalogDb.MediaAssets.Add(assetResult.Value);
        await catalogDb.SaveChangesAsync(ct);

        var evt = CareTimelineEvent.Create(id, caregiverId, "PHOTO_UPLOADED",
            $"Ảnh minh chứng: {task.Name}", taskId: taskId, source: "ONLINE");
        // media_id is set after creation through the dedicated internal helper below.
        db.TimelineEvents.Add(evt.WithMedia(assetResult.Value.Id));
        await db.SaveChangesAsync(ct);

        return Ok(new CareTaskPhotoResponse(taskId, assetResult.Value.Id, upload.Value, evt.RecordedAt));
    }

    private async Task<string[]> GetPhotoUrls(Guid bookingId, Guid taskId, CancellationToken ct)
    {
        var mediaIds = await db.TimelineEvents.AsNoTracking()
            .Where(x => x.BookingId == bookingId && x.TaskId == taskId &&
                        x.EventType == "PHOTO_UPLOADED" && x.MediaId.HasValue)
            .Select(x => x.MediaId!.Value).ToArrayAsync(ct);
        return await catalogDb.MediaAssets.AsNoTracking()
            .Where(x => mediaIds.Contains(x.Id) && x.Url != null)
            .Select(x => x.Url!).ToArrayAsync(ct);
    }

    private static IReadOnlyList<DefaultCareTask> DefaultTasksFor(string? serviceCode)
    {
        var duong = new List<DefaultCareTask>
        {
            new("Vệ sinh cá nhân", "Hỗ trợ vệ sinh, thay đồ và sắp xếp vật dụng cá nhân.", true, true),
            new("Chuẩn bị bữa ăn", "Chuẩn bị đúng ghi chú dinh dưỡng của gia đình và chụp lại phần ăn.", true, true),
            new("Nhắc lịch uống thuốc", "Nhắc người được chăm sóc theo lịch gia đình đã cung cấp.", true, false),
            new("Vận động nhẹ nhàng", "Đồng hành vận động trong phạm vi an toàn, theo tình trạng thực tế.", true, true),
        };
        if (string.Equals(serviceCode, "GENKI_DUONG", StringComparison.OrdinalIgnoreCase))
            return duong;
        if (string.Equals(serviceCode, "GENKI_AN", StringComparison.OrdinalIgnoreCase))
            return duong.Concat(new[]
            {
                new DefaultCareTask("Hoạt động thư giãn", "Đọc sách, trò chuyện, chơi cờ hoặc hoạt động trí não phù hợp.", true, true),
                new DefaultCareTask("Xoa bóp thư giãn", "Hỗ trợ thư giãn nhẹ nhàng theo mong muốn của gia đình.", true, true),
                new DefaultCareTask("Ghi nhận chỉ số theo hướng dẫn", "Chỉ ghi nhận thông tin được gia đình yêu cầu; không chẩn đoán hay điều trị.", true, true),
            }).ToArray();
        if (string.Equals(serviceCode, "GENKI_TAM", StringComparison.OrdinalIgnoreCase))
            return duong.Concat(new[]
            {
                new DefaultCareTask("Hoạt động thư giãn", "Đọc sách, trò chuyện, chơi cờ hoặc hoạt động trí não phù hợp.", true, true),
                new DefaultCareTask("Xoa bóp thư giãn", "Hỗ trợ thư giãn nhẹ nhàng theo mong muốn của gia đình.", true, true),
                new DefaultCareTask("Hỗ trợ phục hồi theo kế hoạch", "Thực hiện đúng hướng dẫn phục hồi đã được gia đình cung cấp.", true, true),
                new DefaultCareTask("Lăn trở và kiểm tra tư thế", "Hỗ trợ đổi tư thế an toàn và ghi nhận tình trạng sau khi thực hiện.", true, true),
                new DefaultCareTask("Ghi nhận chỉ số theo hướng dẫn", "Chỉ ghi nhận thông tin được gia đình yêu cầu; không chẩn đoán hay điều trị.", true, true),
            }).ToArray();
        if (string.Equals(serviceCode, "GENKI_PHUCHOI", StringComparison.OrdinalIgnoreCase))
            return duong.Concat(new[]
            {
                new DefaultCareTask("Bài tập vận động Kaigo", "Hướng dẫn và hỗ trợ bài tập phục hồi chức năng nhẹ nhàng theo hướng dẫn.", true, true),
                new DefaultCareTask("Xoa bóp bấm huyệt phục hồi", "Xoa bóp cơ bắp, hỗ trợ lưu thông khí huyết và giảm căng cứng cơ.", true, true),
                new DefaultCareTask("Ghi nhận phản ứng vận động", "Ghi chú mức độ linh hoạt và phản ứng của người thân sau buổi tập.", true, false),
            }).ToArray();
        if (string.Equals(serviceCode, "GENKI_DONGHANH", StringComparison.OrdinalIgnoreCase))
            return new[]
            {
                new DefaultCareTask("Chuẩn bị trước khi di chuyển", "Kiểm tra sổ khám, thẻ BHYT, thuốc và hỗ trợ trang phục phù hợp.", true, false),
                new DefaultCareTask("Đồng hành và hỗ trợ di chuyển", "Hỗ trợ đi lại an toàn, xe lăn hoặc dìu đỡ khi lên xuống xe.", true, true),
                new DefaultCareTask("Ghi chú dặn dò y tế", "Ghi lại hướng dẫn, lời dặn của bác sĩ hoặc lịch tái khám gửi người thân.", true, true),
                new DefaultCareTask("Hỗ trợ sau khi về nhà", "Giúp cởi áo khoác, nghỉ ngơi, chuẩn bị nước ấm và sắp xếp thuốc mới.", true, false),
            };
        if (string.Equals(serviceCode, "GENKI_DEM", StringComparison.OrdinalIgnoreCase))
            return new[]
            {
                new DefaultCareTask("Hỗ trợ chuẩn bị trước giờ ngủ", "Vệ sinh cá nhân, thay đồ ngủ, chuẩn bị nước ấm và kiểm tra phòng ngủ an toàn.", true, true),
                new DefaultCareTask("Túc trực và theo dõi giấc ngủ", "Quan sát giấc ngủ, kiểm tra nhiệt độ phòng và tiếng động bất thường.", true, false),
                new DefaultCareTask("Hỗ trợ vệ sinh ban đêm", "Dìu đỡ đi vệ sinh đêm cẩn thận, bật đèn chống trượt ngã.", true, true),
                new DefaultCareTask("Hỗ trợ buổi sáng sớm", "Hỗ trợ thức giấc nhẹ nhàng, đo huyết áp/thân nhiệt và ghi chú ca trực đêm.", true, true),
            };
        return Array.Empty<DefaultCareTask>();
    }

    private sealed record DefaultCareTask(string Name, string Description,
        bool IsRequired, bool RequiresPhoto);

    /// <summary>Caregiver bỏ qua task tùy chọn. Không thể bỏ qua task bắt buộc (IsRequired = true).</summary>
    [HttpPut("{taskId:guid}/skip")]
    public async Task<IActionResult> SkipTask(Guid id, Guid taskId, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return Forbid();

        var task = await db.CareTasks.SingleOrDefaultAsync(x => x.Id == taskId && x.BookingId == id, ct);
        if (task is null) return NotFound();
        if (task.IsRequired)
            return BadRequest(new { error = "Nhiem vu bat buoc khong the bo qua." });

        task.Skip();
        await db.SaveChangesAsync(ct);
        return Ok(new CareTaskResponse(task.Id, task.BookingId, task.Name, task.Description,
            task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt,
            await GetPhotoUrls(task.BookingId, task.Id, ct)));
    }
}

public sealed record CreateCareTaskRequest(string Name, string? Description = null,
    bool IsRequired = false, bool RequiresPhoto = false, int SortOrder = 0);

public sealed record CareTaskResponse(Guid Id, Guid BookingId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, string Status, DateTimeOffset? CompletedAt,
    string[] PhotoUrls);
public sealed record CareTaskPhotoResponse(Guid TaskId, Guid MediaId, string Url, DateTimeOffset UploadedAt);
