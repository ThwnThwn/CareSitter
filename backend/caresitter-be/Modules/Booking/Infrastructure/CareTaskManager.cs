using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class CareTaskManager(
    BookingDbContext db,
    IBookingMediaStore mediaStore,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMediaService mediaService,
    IHubContext<CareTrackingHub> hub,
    ILogger<CareTaskManager> logger) : ICareTaskManager
{
    public async Task<Result<IReadOnlyList<CareTaskResponse>>> ListAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == bookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        var canRead = booking.CustomerId == userId || currentUser.IsInRole("ADMIN");
        if (!canRead && booking.CaregiverId is { } caregiverId)
            canRead = await people.IsCaregiverForBookingAsync(caregiverId, userId, ct);
        if (!canRead) return BookingErrors.Forbidden();

        var tasks = await db.CareTasks.AsNoTracking().Where(x => x.BookingId == bookingId)
            .OrderBy(x => x.SortOrder).ToListAsync(ct);
        var photoUrls = await GetPhotoUrlsByTaskAsync(bookingId, tasks.Select(x => x.Id).ToArray(), ct);
        return Result.Success<IReadOnlyList<CareTaskResponse>>(tasks.Select(x =>
            ToResponse(x, photoUrls.GetValueOrDefault(x.Id) ?? [])).ToArray());
    }

    public async Task<Result<CareTaskResponse>> CreateAsync(
        Guid bookingId, string name, string? description, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var gate = await RequireActiveAssignedCaregiver(bookingId, userId, ct);
        if (gate.IsFailure) return gate.Error;
        if (!gate.Value.AllowAdHocTasks)
            return Error.Validation("care_task.adhoc_disabled",
                "Gói dịch vụ này có checklist cố định, không cho phép thêm công việc phát sinh.");
        if (string.IsNullOrWhiteSpace(name) || name.Trim().Length is < 3 or > 255)
            return Error.Validation("care_task.name", "Tên công việc phát sinh phải có từ 3 đến 255 ký tự.");
        if (description?.Trim().Length > 500)
            return Error.Validation("care_task.description", "Ghi chú công việc tối đa 500 ký tự.");
        if (await db.CareTasks.CountAsync(
                x => x.BookingId == bookingId && x.Source == "CAREGIVER_AD_HOC", ct) >= 20)
            return Error.Validation("care_task.limit", "Mỗi ca chỉ được thêm tối đa 20 công việc phát sinh.");

        var nextOrder = (await db.CareTasks.Where(x => x.BookingId == bookingId)
            .Select(x => (int?)x.SortOrder).MaxAsync(ct) ?? 0) + 1;
        var task = CareTask.Create(bookingId, name.Trim(), description?.Trim(),
            false, false, nextOrder, "CAREGIVER_AD_HOC", userId);
        db.CareTasks.Add(task);
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, []);
        await RunPostCommitAsync("created care task broadcast",
            () => BroadcastTaskUpdate(bookingId, response, ct));
        return response;
    }

    public async Task<Result<CareTaskResponse>> CompleteAsync(
        Guid bookingId, Guid taskId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var gate = await RequireActiveAssignedCaregiver(bookingId, userId, ct);
        if (gate.IsFailure) return gate.Error;
        var task = await db.CareTasks.SingleOrDefaultAsync(
            x => x.Id == taskId && x.BookingId == bookingId, ct);
        if (task is null) return BookingErrors.NotFound();
        if (task.Status == "COMPLETED")
            return ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        if (task.Status != "PENDING")
            return Error.Conflict("care_task.finished",
                "Task đã ở trạng thái kết thúc và không thể hoàn thành.");
        if (task.RequiresPhoto && !await db.TimelineEvents.AnyAsync(x =>
                x.BookingId == bookingId && x.TaskId == taskId &&
                x.EventType == "PHOTO_UPLOADED", ct))
            return Error.Validation("care_task.photo_required",
                "Nhiệm vụ này cần có ảnh minh chứng trước khi hoàn thành.");

        task.MarkCompleted(userId);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            bookingId, gate.Value.CaregiverId, "TASK_DONE",
            $"Hoàn thành: {task.Name}", taskId: taskId));
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitAsync("completed care task broadcast",
            () => BroadcastTaskUpdate(bookingId, response, ct));
        return response;
    }

    public async Task<Result<CareTaskPhotoResponse>> UploadPhotoAsync(
        UploadCareTaskPhotoCommand request, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        if (request.Length <= 0)
            return Error.Validation("care_task.photo_empty", "Vui lòng chọn một ảnh.");
        if (request.Length > 10 * 1024 * 1024)
            return Error.Validation("care_task.photo_large", "Ảnh không được vượt quá 10 MB.");
        if (!AllowedPhotoContentTypes.Contains(request.ContentType))
            return Error.Validation("care_task.photo_type", "Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP.");
        var gate = await RequireActiveAssignedCaregiver(request.BookingId, userId, ct);
        if (gate.IsFailure) return gate.Error;
        var task = await db.CareTasks.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == request.TaskId && x.BookingId == request.BookingId, ct);
        if (task is null) return BookingErrors.NotFound();

        var upload = await mediaService.UploadImageAsync(
            request.Content, request.FileName, "CareSitter/Checklist", ct);
        if (upload.IsFailure) return upload.Error;
        var media = await mediaStore.AddPhotoAsync(
            userId, request.BookingId, upload.Value,
            request.ContentType, request.Length, ct);
        if (media.IsFailure) return media.Error;

        var timelineEvent = CareTimelineEvent.Create(
            request.BookingId, gate.Value.CaregiverId, "PHOTO_UPLOADED",
            $"Ảnh minh chứng: {task.Name}", taskId: request.TaskId, source: "ONLINE");
        db.TimelineEvents.Add(timelineEvent.WithMedia(media.Value));
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task,
            await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitAsync("care task photo broadcast",
            () => BroadcastTaskUpdate(request.BookingId, response, ct));
        return new CareTaskPhotoResponse(
            request.TaskId, media.Value, upload.Value, timelineEvent.RecordedAt);
    }

    public async Task<Result<CareTaskResponse>> SkipAsync(
        Guid bookingId, Guid taskId, string reason, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return BookingErrors.Unauthenticated();
        var gate = await RequireActiveAssignedCaregiver(bookingId, userId, ct);
        if (gate.IsFailure) return gate.Error;
        var task = await db.CareTasks.SingleOrDefaultAsync(
            x => x.Id == taskId && x.BookingId == bookingId, ct);
        if (task is null) return BookingErrors.NotFound();
        if (task.Status == "SKIPPED")
            return ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        if (task.Status != "PENDING")
            return Error.Conflict("care_task.finished",
                "Task đã ở trạng thái kết thúc và không thể bỏ qua.");
        if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length < 3)
            return Error.Validation("care_task.skip_reason",
                "Cần nhập lý do bỏ qua tối thiểu 3 ký tự.");

        task.Skip(reason);
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            bookingId, gate.Value.CaregiverId, "TASK_SKIPPED", $"Bỏ qua: {task.Name}",
            reason.Trim(), taskId: taskId));
        await db.SaveChangesAsync(ct);
        var response = ToResponse(task, await GetPhotoUrls(task.BookingId, task.Id, ct));
        await RunPostCommitAsync("skipped care task broadcast",
            () => BroadcastTaskUpdate(bookingId, response, ct));
        return response;
    }

    private async Task<Result<CareTaskGate>> RequireActiveAssignedCaregiver(
        Guid bookingId, Guid userId, CancellationToken ct)
    {
        var booking = await db.Bookings.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == bookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.Status != BookingStatus.InProgress || booking.ActualStart is null)
            return Error.Conflict("care_task.checkin_required",
                "Checklist chỉ được cập nhật sau khi caregiver check-in.");
        if (booking.CaregiverId is not { } caregiverId ||
            !await people.IsCaregiverForBookingAsync(caregiverId, userId, ct))
            return BookingErrors.Forbidden();
        return new CareTaskGate(caregiverId, booking.AllowAdHocTasks);
    }

    private async Task<Dictionary<Guid, string[]>> GetPhotoUrlsByTaskAsync(
        Guid bookingId, Guid[] taskIds, CancellationToken ct)
    {
        var photoEvents = await db.TimelineEvents.AsNoTracking().Where(x =>
                x.BookingId == bookingId && x.EventType == "PHOTO_UPLOADED" &&
                x.TaskId.HasValue && Enumerable.Contains(taskIds, x.TaskId.Value) && x.MediaId.HasValue)
            .Select(x => new { x.TaskId, x.MediaId }).ToListAsync(ct);
        var mediaIds = photoEvents.Select(x => x.MediaId!.Value).Distinct().ToArray();
        var urls = await mediaStore.GetUrlsAsync(mediaIds, ct);
        return photoEvents.GroupBy(x => x.TaskId!.Value).ToDictionary(
            x => x.Key,
            x => x.Select(item => urls.GetValueOrDefault(item.MediaId!.Value))
                .Where(url => url is not null).Cast<string>().ToArray());
    }

    private async Task<string[]> GetPhotoUrls(Guid bookingId, Guid taskId, CancellationToken ct)
    {
        var result = await GetPhotoUrlsByTaskAsync(bookingId, [taskId], ct);
        return result.GetValueOrDefault(taskId) ?? [];
    }

    private async Task BroadcastTaskUpdate(
        Guid bookingId, CareTaskResponse task, CancellationToken ct)
    {
        var counts = await db.CareTasks.AsNoTracking().Where(x => x.BookingId == bookingId)
            .GroupBy(_ => 1).Select(group => new
            {
                Completed = group.Count(x => x.Status == "COMPLETED"),
                Total = group.Count(),
                Skipped = group.Count(x => x.Status == "SKIPPED")
            }).SingleOrDefaultAsync(ct);
        await hub.Clients.Group(CareTrackingHub.BookingGroup(bookingId)).SendAsync(
            "CareTaskUpdated", new
            {
                bookingId,
                completed = counts?.Completed ?? 0,
                total = counts?.Total ?? 0,
                skipped = counts?.Skipped ?? 0,
                task
            }, ct);
    }

    private async Task RunPostCommitAsync(string action, Func<Task> operation)
    {
        try { await operation(); }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Checklist was committed, but post-commit action {PostCommitAction} failed.", action);
        }
    }

    private static CareTaskResponse ToResponse(CareTask task, string[] photoUrls) => new(
        task.Id, task.BookingId, task.Name, task.Description, task.IsRequired,
        task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt, photoUrls,
        task.Source, task.SkipReason, task.CompletedBy, task.CreatedAt);

    private sealed record CareTaskGate(Guid CaregiverId, bool AllowAdHocTasks);

    private static readonly HashSet<string> AllowedPhotoContentTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg", "image/png", "image/webp"
        };
}
