using System.Text.Json;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Cung cấp API tìm kiếm và xem thông tin caregiver đã được duyệt KYC.
/// Hỗ trợ bộ lọc: thành phố, quận, kỹ năng, đánh giá tối thiểu, trạng thái và khủng giờ rảnh.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/caregivers")]
public sealed class CaregiversController(PeopleDbContext db) : ControllerBase
{
    /// <summary>
    /// Tìm kiếm danh sách caregiver đã APPROVED, hỗ trợ lọc nhiều tiêu chí và phân trang.
    /// Xếp theo điểm đánh giá trung bình giảm dần.
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> List(string? city, string? district, string? skill,
        decimal? minRating, string? availabilityStatus, DateTimeOffset? start, DateTimeOffset? end,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var query = string.IsNullOrWhiteSpace(skill)
            ? db.CaregiverProfiles.AsQueryable()
            : db.CaregiverProfiles.FromSqlInterpolated(
                $"SELECT * FROM people.caregiver_profiles WHERE skills::text ILIKE {"%" + skill + "%"}");
        query = query.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "APPROVED");
        if (!string.IsNullOrWhiteSpace(city))
            query = query.Where(x => x.ServiceCity == city);
        if (!string.IsNullOrWhiteSpace(district))
            query = query.Where(x => x.ServiceDistrict == district);
        if (!string.IsNullOrWhiteSpace(availabilityStatus))
            query = query.Where(x => x.AvailabilityStatus == availabilityStatus.ToUpper());
        if (minRating.HasValue)
            query = query.Where(x => x.RatingAvg >= minRating.Value);
        if (start.HasValue && end.HasValue)
            query = query.Where(x => db.CaregiverAvailabilities.Any(a =>
                a.CaregiverId == x.Id && a.Status == "AVAILABLE" &&
                a.StartAt <= start.Value && a.EndAt >= end.Value));

        var total = await query.CountAsync(ct);
        var entities = await query.OrderByDescending(x => x.RatingAvg)
            .ThenByDescending(x => x.RatingCount).Skip((page - 1) * pageSize)
            .Take(pageSize).ToListAsync(ct);
        return Ok(new { items = entities.Select(ToCaregiver), total, page, pageSize });
    }

    /// <summary>Xem hồ sơ đầy đủ của một caregiver đã APPROVED theo ID.</summary>
    [HttpGet("{id:guid}")]
    [AllowAnonymous]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var entity = await db.CaregiverProfiles.AsNoTracking().SingleOrDefaultAsync(x =>
            x.Id == id && x.DeletedAt == null && x.KycStatus == "APPROVED", ct);
        return entity is null ? NotFound() : Ok(ToCaregiver(entity));
    }

    /// <summary>
    /// Lấy danh sách khung giờ rảnh của caregiver, có thể lọc theo khoảng thời gian.
    /// Dùng cho bước chọn caregiver phù hợp khi đặt lịch.
    /// </summary>
    [HttpGet("{id:guid}/availability")]
    public async Task<IActionResult> GetAvailability(Guid id,
        DateTimeOffset? from, DateTimeOffset? to, CancellationToken ct)
    {
        var query = db.CaregiverAvailabilities.AsNoTracking()
            .Where(x => x.CaregiverId == id && x.Status == "AVAILABLE");
        if (from.HasValue) query = query.Where(x => x.EndAt > from.Value);
        if (to.HasValue) query = query.Where(x => x.StartAt < to.Value);
        var slots = await query.OrderBy(x => x.StartAt)
            .Select(x => new AvailabilityResponse(x.Id, x.StartAt, x.EndAt, x.Status)).ToListAsync(ct);
        return Ok(slots);
    }

    private static CaregiverResponse ToCaregiver(CaregiverProfile x) => new(x.Id, x.UserId,
        x.FullName, x.Bio, x.YearsOfExperience, x.HourlyRateExpected, x.RatingAvg,
        x.RatingCount, x.AvailabilityStatus, Json(x.Skills), x.ServiceCity, x.ServiceDistrict);

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();
}

public sealed record CaregiverResponse(Guid Id, Guid UserId, string? FullName, string? Bio,
    int? YearsOfExperience, long? HourlyRateExpected, decimal RatingAvg, int RatingCount,
    string AvailabilityStatus, JsonElement? Skills, string? ServiceCity, string? ServiceDistrict);

public sealed record AvailabilityResponse(Guid Id, DateTimeOffset StartAt,
    DateTimeOffset EndAt, string Status);
