using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
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
    BookingDbContext db, ICurrentUser currentUser, IPeopleLookupService people) : ControllerBase
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

        return Ok(tasks.Select(t => new CareTaskResponse(
            t.Id, t.BookingId, t.Name, t.Description, t.IsRequired,
            t.RequiresPhoto, t.SortOrder, t.Status, t.CompletedAt)));
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
                task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt));
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

        task.MarkDone();
        db.TimelineEvents.Add(CareTimelineEvent.Create(
            id, caregiverId, "TASK_DONE", $"Hoan thanh: {task.Name}", taskId: taskId));

        await db.SaveChangesAsync(ct);
        return Ok(new CareTaskResponse(task.Id, task.BookingId, task.Name, task.Description,
            task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt));
    }

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
            task.IsRequired, task.RequiresPhoto, task.SortOrder, task.Status, task.CompletedAt));
    }
}

public sealed record CreateCareTaskRequest(string Name, string? Description = null,
    bool IsRequired = false, bool RequiresPhoto = false, int SortOrder = 0);

public sealed record CareTaskResponse(Guid Id, Guid BookingId, string Name, string? Description,
    bool IsRequired, bool RequiresPhoto, int SortOrder, string Status, DateTimeOffset? CompletedAt);
