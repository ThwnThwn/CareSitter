using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog.Infrastructure;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Catalog.Controllers;

/// <summary>
/// Quản lý danh mục dịch vụ chăm sóc (Genki Dưỡng / An / Tâm).
/// Cho phép liệt kê, xem chi tiết và báo giá theo khung giờ đặt lịch.
/// </summary>
[ApiController]
[Route("api/v1/services")]
public sealed class ServicesController(CatalogDbContext db, IPricingService pricing) : ControllerBase
{
    /// <summary>Lấy danh sách tất cả dịch vụ đang hoạt động, sắp xếp theo tên.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var items = await db.ServiceTypes.AsNoTracking().Where(x => x.IsActive)
            .OrderBy(x => x.Name).Select(x => new
            {
                x.Id, x.Code, x.Name, x.Description, x.DefaultDurationMinutes, x.AllowAdHocTasks,
                pricing = db.PricingRules.AsNoTracking()
                    .Where(p => p.ServiceTypeId == x.Id && p.IsActive &&
                        p.EffectiveFrom <= now && (p.EffectiveTo == null || p.EffectiveTo > now))
                    .OrderByDescending(p => p.EffectiveFrom)
                    .Select(p => new { p.BaseHourlyPrice, p.PlatformFeePercent })
                    .FirstOrDefault()
            }).ToListAsync(ct);
        return Ok(items.Select(x => new
        {
            x.Id,
            x.Code,
            x.Name,
            x.Description,
            x.DefaultDurationMinutes,
            x.AllowAdHocTasks,
            BaseHourlyPrice = x.pricing?.BaseHourlyPrice ?? 0,
            PlatformFeePercent = x.pricing?.PlatformFeePercent ?? 0m
        }));
    }

    /// <summary>Xem chi tiết một dịch vụ theo ID. Trả về 404 nếu không tồn tại hoặc đã vô hiệu hóa.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var item = await db.ServiceTypes.AsNoTracking().Where(x => x.Id == id && x.IsActive)
            .Select(x => new { x.Id, x.Code, x.Name, x.Description, x.DefaultDurationMinutes, x.AllowAdHocTasks })
            .SingleOrDefaultAsync(ct);
        if (item is null) return NotFound();

        var pricing = await db.PricingRules.AsNoTracking()
            .Where(p => p.ServiceTypeId == id && p.IsActive &&
                p.EffectiveFrom <= now && (p.EffectiveTo == null || p.EffectiveTo > now))
            .OrderByDescending(p => p.EffectiveFrom)
            .Select(p => new { p.BaseHourlyPrice, p.PlatformFeePercent })
            .FirstOrDefaultAsync(ct);
        return Ok(new
        {
            item.Id,
            item.Code,
            item.Name,
            item.Description,
            item.DefaultDurationMinutes,
            item.AllowAdHocTasks,
            BaseHourlyPrice = pricing?.BaseHourlyPrice ?? 0,
            PlatformFeePercent = pricing?.PlatformFeePercent ?? 0m
        });
    }

    /// <summary>
    /// Tính giá dự kiến cho dịch vụ theo khung giờ (ScheduledStart → ScheduledEnd).
    /// Yêu cầu xác thực. Dùng trước bước xác nhận đặt lịch.
    /// </summary>
    [HttpPost("{id:guid}/quote")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Quote(Guid id, [FromBody] QuoteRequest request, CancellationToken ct)
    {
        var result = await pricing.QuoteAsync(id, request.ScheduledStart, request.ScheduledEnd, ct);
        if (result.IsSuccess) return Ok(result.Value);
        return result.Error.Type == SharedKernel.Results.ErrorType.NotFound
            ? NotFound(new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message })
            : BadRequest(new ProblemDetails { Title = result.Error.Code, Detail = result.Error.Message });
    }
}

public sealed record QuoteRequest(DateTimeOffset ScheduledStart, DateTimeOffset ScheduledEnd);
