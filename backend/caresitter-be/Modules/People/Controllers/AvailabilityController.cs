using CareSitter.Infrastructure.Security;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Quản lý lịch rảnh (availability slots) của caregiver hiện tại.
/// Caregiver tự đăng ký, xem và xóa các khung giờ mình sẵn sàng đón ca.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/caregivers/me/availability")]
public sealed class AvailabilityController(PeopleDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>
    /// Caregiver đăng ký một khung giờ rảnh mới vào lịch của mình.
    /// Hệ thống tạo slot với trạng thái mặc định là AVAILABLE.
    /// Slot này sẽ được dùng để Customer lọc caregiver khi đặt lịch.
    /// </summary>
    /// <param name="req">Thời gian bắt đầu, kết thúc và trạng thái slot (mặc định: AVAILABLE).</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>201 Created kèm thông tin slot vừa tạo.</returns>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateAvailabilityRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var profile = await db.CaregiverProfiles.AsNoTracking()
            .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
        if (profile is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        var slot = CaregiverAvailability.Create(profile.Id, req.StartAt, req.EndAt,
            req.Status ?? "AVAILABLE", "CAREGIVER");
        if (slot.IsFailure) return Problem(slot.Error);

        db.CaregiverAvailabilities.Add(slot.Value);
        await db.SaveChangesAsync(ct);
        return Created($"/api/v1/caregivers/me/availability/{slot.Value.Id}",
            ToResponse(slot.Value));
    }

    /// <summary>
    /// Caregiver xem danh sách lịch rảnh của chính mình, có thể lọc theo khoảng thời gian.
    /// Chỉ trả về các slot thuộc CaregiverProfile hiện tại (tự động lấy theo JWT).
    /// </summary>
    /// <param name="from">Nếu truyền vào, chỉ lấy slot kết thúc sau mốc này.</param>
    /// <param name="to">Nếu truyền vào, chỉ lấy slot bắt đầu trước mốc này.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>Danh sách AvailabilitySlotResponse sắp xếp theo thời gian tăng dần.</returns>
    [HttpGet]
    public async Task<IActionResult> ListMy(DateTimeOffset? from = null, DateTimeOffset? to = null,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var caregiverId = await db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.UserId == userId && x.DeletedAt == null)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(ct);
        if (caregiverId is null)
            return NotFound(new { error = "Caregiver profile khong ton tai." });

        var query = db.CaregiverAvailabilities.AsNoTracking()
            .Where(x => x.CaregiverId == caregiverId.Value);
        if (from.HasValue) query = query.Where(x => x.EndAt > from.Value);
        if (to.HasValue) query = query.Where(x => x.StartAt < to.Value);

        var slots = await query.OrderBy(x => x.StartAt)
            .Select(x => new AvailabilitySlotResponse(x.Id, x.StartAt, x.EndAt, x.Status, x.Source))
            .ToListAsync(ct);

        return Ok(slots);
    }

    /// <summary>
    /// Caregiver xóa một khung giờ rảnh cụ thể của mình theo ID.
    /// Chỉ xóa được slot thuộc CaregiverProfile hiện tại (kiểm tra chủ sở hữu).
    /// Lưu ý: nếu booking đã được tạo trong khoảng này, slot sẽ không tự bị ảnh hưởng.
    /// </summary>
    /// <param name="id">ID của slot cần xóa.</param>
    /// <param name="ct">Token hủy tác vụ bất đồng bộ.</param>
    /// <returns>204 NoContent nếu xóa thành công, 404 nếu không tìm thấy.</returns>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        var caregiverId = await db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.UserId == userId && x.DeletedAt == null)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(ct);
        if (caregiverId is null) return NotFound();

        var slot = await db.CaregiverAvailabilities
            .SingleOrDefaultAsync(x => x.Id == id && x.CaregiverId == caregiverId.Value, ct);
        if (slot is null) return NotFound();

        db.CaregiverAvailabilities.Remove(slot);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static AvailabilitySlotResponse ToResponse(CaregiverAvailability x) =>
        new(x.Id, x.StartAt, x.EndAt, x.Status, x.Source);

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.NotFound => NotFound(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

public sealed record CreateAvailabilityRequest(DateTimeOffset StartAt, DateTimeOffset EndAt,
    string? Status = "AVAILABLE");
public sealed record AvailabilitySlotResponse(Guid Id, DateTimeOffset StartAt,
    DateTimeOffset EndAt, string Status, string Source);
