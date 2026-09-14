using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;

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
    IMediaService mediaService,
    IHubContext<CareTrackingHub> hub,
    ILogger<CareTasksController> logger) : ControllerBase
{
    /// <summary>Lấy toàn bộ task của booking, sắp xếp theo SortOrder.</summary>
    [HttpGet]
    public async Task<IActionResult> List(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        if (booking is null) return NotFound();

        var canRead = booking.CustomerId == userId || currentUser.IsInRole("ADMIN");
        if (!canRead && booking.CaregiverId is { } caregiverId)
            canRead = await people.IsCaregiverForBookingAsync(caregiverId, userId, ct);
        if (!canRead) return Forbid();

        var tasks = await db.CareTasks.AsNoTracking()
            .Where(x => x.BookingId == id)
            .OrderBy(x => x.SortOrder)
            .ToListAsync(ct);

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

        return Ok(tasks.Select(t => ToResponse(t,
            photoEvents.Where(x => x.TaskId == t.Id && x.MediaId.HasValue)
                .Select(x => mediaUrls.GetValueOrDefault(x.MediaId!.Value))
                .Where(x => x != null).Cast<string>().ToArray())));
    }

    /// <summary>Caregiver thêm công việc phát sinh sau khi đã check-in.</summary>
    [HttpPost]
    public async Task<IActionResult> Create(Guid id, [FromBody] CreateCareTaskRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var gate = await RequireActiveAssignedCaregiver(id, userId, ct);
        if (gate.Error is not null) return gate.Error;
        if (!gate.AllowAdHocTasks)
            return BadRequest(new { error = "Gói dịch vụ này có checklist cố định, không cho phép thêm công việc phát sinh." });
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length is < 3 or > 255)
            return BadRequest(new { error = "Tên công việc phát sinh phải có từ 3 đến 255 ký tự." });
        if (request.Description?.Trim().Length > 500)
            return BadRequest(new { error = "Ghi chú công việc tối đa 500 ký tự." });
        if (await db.CareTasks.CountAsync(x => x.BookingId == id && x.Source == "CAREGIVER_AD_HOC", ct) >= 20)
            return BadRequest(new { error = "Mỗi ca chỉ được thêm tối đa 20 công việc phát sinh." });

        var nextOrder = (await db.CareTasks.Where(x => x.BookingId == id)
            .Select(x => (int?)x.SortOrder).MaxAsync(ct) ?? 0) + 1;
        var task = CareTask.Create(id, request.Name.Trim(), request.Description?.Trim(),
            isRequired: false, requiresPhoto: false, sortOrder: nextOrder,
            source: "CAREGIVER_AD_HOC", createdBy: userId);
        db.CareTasks.Add(task);
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, Array.Empty<string>());
        await RunPostCommitActionAsync("created care task broadcast", () => BroadcastTaskUpdate(id, response, ct));
        return Created($"/api/v1/bookings/{id}/tasks/{task.Id}", response);
    }

    /// <summary>Caregiver đánh dấu task đã hoàn thành và ghi sự kiện TASK_DONE vào timeline.</summary>
    [HttpPatch("{taskId:guid}/complete")]
    [HttpPut("{taskId:guid}/complete")]
    public async Task<IActionResult> CompleteTask(Guid id, Guid taskId, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var gate = await RequireActiveAssignedCaregiver(id, userId, ct);
        if (gate.Error is not null) return gate.Error;

        var task = await db.CareTasks.SingleOrDefaultAsync(x => x.Id == taskId && x.BookingId == id, ct);
        if (task is null) return NotFound();

        if (task.Status == "COMPLETED")
            return Ok(ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct)));
        if (task.Status != "PENDING")
            return Conflict(new { error = "Task đã ở trạng thái kết thúc và không thể hoàn thành." });
        if (task.RequiresPhoto && !await db.TimelineEvents.AnyAsync(
                x => x.BookingId == id && x.TaskId == taskId && x.EventType == "PHOTO_UPLOADED", ct))
            return BadRequest(new { error = "Nhiệm vụ này cần có ảnh minh chứng trước khi hoàn thành." });

        task.MarkCompleted(userId);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            id, gate.CaregiverId!.Value, "TASK_DONE", $"Hoàn thành: {task.Name}", taskId: taskId));

        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitActionAsync("completed care task broadcast", () => BroadcastTaskUpdate(id, response, ct));
        return Ok(response);
    }

    /// <summary>Upload ảnh minh chứng cho một task của caregiver được assign.</summary>
    [HttpPost("{taskId:guid}/photos")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadPhoto(Guid id, Guid taskId, IFormFile file, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (file is null || file.Length == 0) return BadRequest(new { error = "Vui lòng chọn một ảnh." });
        if (file.Length > 10 * 1024 * 1024) return BadRequest(new { error = "Ảnh không được vượt quá 10 MB." });

        var allowedTypes = new[] { "image/jpeg", "image/png", "image/webp" };
        if (!allowedTypes.Contains(file.ContentType, StringComparer.OrdinalIgnoreCase))
            return BadRequest(new { error = "Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP." });

        var gate = await RequireActiveAssignedCaregiver(id, userId, ct);
        if (gate.Error is not null) return gate.Error;

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

        var evt = CareTimelineEvent.Create(id, gate.CaregiverId!.Value, "PHOTO_UPLOADED",
            $"Ảnh minh chứng: {task.Name}", taskId: taskId, source: "ONLINE");
        // media_id is set after creation through the dedicated internal helper below.
        db.TimelineEvents.Add(evt.WithMedia(assetResult.Value.Id));
        await db.SaveChangesAsync(ct);

        var taskResponse = ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitActionAsync("care task photo broadcast", () => BroadcastTaskUpdate(id, taskResponse, ct));
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

    [HttpPatch("{taskId:guid}/skip")]
    [HttpPut("{taskId:guid}/skip")]
    public async Task<IActionResult> SkipTask(Guid id, Guid taskId, [FromBody] SkipCareTaskRequest request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var gate = await RequireActiveAssignedCaregiver(id, userId, ct);
        if (gate.Error is not null) return gate.Error;

        var task = await db.CareTasks.SingleOrDefaultAsync(x => x.Id == taskId && x.BookingId == id, ct);
        if (task is null) return NotFound();
        if (task.Status == "SKIPPED")
            return Ok(ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct)));
        if (task.Status != "PENDING")
            return Conflict(new { error = "Task đã ở trạng thái kết thúc và không thể bỏ qua." });
        if (string.IsNullOrWhiteSpace(request.SkipReason) || request.SkipReason.Trim().Length < 3)
            return BadRequest(new { error = "Cần nhập lý do bỏ qua tối thiểu 3 ký tự." });

        task.Skip(request.SkipReason);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            id, gate.CaregiverId!.Value, "TASK_SKIPPED", $"Bỏ qua: {task.Name}",
            request.SkipReason.Trim(), taskId: taskId));
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitActionAsync("skipped care task broadcast", () => BroadcastTaskUpdate(id, response, ct));
        return Ok(response);
    }

    private async Task<(Guid? CaregiverId, bool AllowAdHocTasks, IActionResult? Error)> RequireActiveAssignedCaregiver(
        Guid bookingId, Guid userId, CancellationToken ct)
    {
        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return (null, false, NotFound());
        if (booking.Status != BookingStatus.InProgress || booking.ActualStart is null)
            return (null, false, Conflict(new { error = "Checklist chỉ được cập nhật sau khi caregiver check-in." }));
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return (null, false, Forbid());
        return (caregiverId, booking.AllowAdHocTasks, null);
    }

    private static CareTaskResponse ToResponse(CareTask task, string[] photoUrls) => new(
        task.Id, task.BookingId, task.Name, task.Description, task.IsRequired,
        task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt, photoUrls,
        task.Source, task.SkipReason, task.CompletedBy, task.CreatedAt);

    private async Task BroadcastTaskUpdate(Guid bookingId, CareTaskResponse task, CancellationToken ct)
    {
        var counts = await db.CareTasks.AsNoTracking().Where(x => x.BookingId == bookingId)
            .GroupBy(_ => 1).Select(group => new
            {
                Completed = group.Count(x => x.Status == "COMPLETED"),
                Total = group.Count(),
                Skipped = group.Count(x => x.Status == "SKIPPED")
            }).SingleOrDefaultAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync("CareTaskUpdated",
            new { bookingId, completed = counts?.Completed ?? 0, total = counts?.Total ?? 0,
                skipped = counts?.Skipped ?? 0, task }, ct);
    }

    private async Task RunPostCommitActionAsync(string action, Func<Task> operation)
    {
        try
        {
            await operation();
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Checklist was committed, but post-commit action {PostCommitAction} failed.", action);
        }
    }
}

public sealed record CreateCareTaskRequest(string Name, string? Description = null,
    bool IsRequired = false, bool RequiresPhoto = false, int SortOrder = 0);
public sealed record SkipCareTaskRequest(string SkipReason);

public sealed record CareTaskResponse(Guid Id, Guid BookingId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, string Status, DateTimeOffset? CompletedAt,
    string[] PhotoUrls, string Source, string? SkipReason, Guid? CompletedBy, DateTimeOffset CreatedAt);
public sealed record CareTaskPhotoResponse(Guid TaskId, Guid MediaId, string Url, DateTimeOffset UploadedAt);
