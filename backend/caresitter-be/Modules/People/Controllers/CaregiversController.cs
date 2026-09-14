using System.Text.Json;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.People.Controllers;

/// <summary>
/// Cung cấp API tìm kiếm và xem thông tin caregiver đã được duyệt KYC.
/// Khi lat/lng được cung cấp: filter theo PostGIS ST_Distance ≤ ServiceRadiusMeters, sort gần → xa.
/// Khi không có lat/lng: fallback về lọc text city/district như cũ.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/caregivers")]
public sealed class CaregiversController(PeopleDbContext db) : ControllerBase
{
    private const int DefaultRadiusMeters = 10_000; // 10 km mặc định

    /// <summary>
    /// Tìm kiếm danh sách caregiver đã APPROVED, hỗ trợ lọc nhiều tiêu chí và phân trang.
    /// Truyền lat+lng để kích hoạt spatial filter (PostGIS); bỏ qua để dùng city/district text.
    /// </summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> List(
        double? lat, double? lng,
        string? city, string? district, string? skill,
        decimal? minRating, string? availabilityStatus,
        DateTimeOffset? start, DateTimeOffset? end,
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

        if (!string.IsNullOrWhiteSpace(availabilityStatus))
            query = query.Where(x => x.AvailabilityStatus == availabilityStatus.ToUpper());
        if (minRating.HasValue)
            query = query.Where(x => x.RatingAvg >= minRating.Value);
        // start/end được giữ lại để tương thích query cũ; caregiver tự kiểm tra
        // lịch và xác nhận ca, hệ thống chỉ chặn trùng booking khi nhận ca.

        bool useSpatial = lat.HasValue && lng.HasValue
                          && lat.Value is >= -90 and <= 90
                          && lng.Value is >= -180 and <= 180;

        if (useSpatial)
        {
            var customerPoint = new Point(lng!.Value, lat!.Value) { SRID = 4326 };

            // Chỉ lấy caregiver đã khai báo vị trí và nằm trong bán kính phục vụ
            query = query.Where(x =>
                x.ServiceCenterLocation != null &&
                x.ServiceCenterLocation.IsWithinDistance(customerPoint,
                    x.ServiceRadiusMeters != null ? x.ServiceRadiusMeters.Value : DefaultRadiusMeters));

            var total = await query.CountAsync(ct);

            // Sort: gần nhất trước, sau đó rating
            var entities = await query
                .OrderBy(x => x.ServiceCenterLocation!.Distance(customerPoint))
                .ThenByDescending(x => x.RatingAvg)
                .ThenByDescending(x => x.RatingCount)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            var items = entities.Select(x => ToCaregiver(x,
                distanceMeters: (int?)x.ServiceCenterLocation?.Distance(customerPoint)));

            return Ok(new { items, total, page, pageSize });
        }
        else
        {
            // Fallback: text filter
            if (!string.IsNullOrWhiteSpace(city))
                query = query.Where(x => x.ServiceCity == city);
            if (!string.IsNullOrWhiteSpace(district))
                query = query.Where(x => x.ServiceDistrict == district);

            var total = await query.CountAsync(ct);
            var entities = await query
                .OrderByDescending(x => x.RatingAvg)
                .ThenByDescending(x => x.RatingCount)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            return Ok(new { items = entities.Select(x => ToCaregiver(x)), total, page, pageSize });
        }
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

    private static CaregiverResponse ToCaregiver(CaregiverProfile x, int? distanceMeters = null) =>
        new(x.Id, x.UserId, x.FullName, x.Bio, x.YearsOfExperience,
            x.RatingAvg, x.RatingCount, x.AvailabilityStatus, Json(x.Skills),
            x.ServiceCity, x.ServiceDistrict,
            x.ServiceCenterLocation != null ? x.ServiceCenterLocation.Y : null,
            x.ServiceCenterLocation != null ? x.ServiceCenterLocation.X : null,
            x.ServiceRadiusMeters, distanceMeters);

    private static JsonElement? Json(string? value) => string.IsNullOrWhiteSpace(value)
        ? null : JsonDocument.Parse(value).RootElement.Clone();
}

public sealed record CaregiverResponse(
    Guid Id, Guid UserId, string? FullName, string? Bio,
    int? YearsOfExperience,
    decimal RatingAvg, int RatingCount,
    string AvailabilityStatus, JsonElement? Skills,
    string? ServiceCity, string? ServiceDistrict,
    // Vĩ độ tâm vùng phục vụ (null nếu caregiver chưa khai báo)
    double? ServiceCenterLat, double? ServiceCenterLng,
    int? ServiceRadiusMeters,
    // Khoảng cách (mét) từ điểm khách hàng — chỉ có khi gọi với lat/lng
    int? DistanceMeters);

