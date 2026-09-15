using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CreateReview;
using CareSitter.Modules.Support.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý đánh giá (Review) dịch vụ sau khi Booking hoàn thành.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/reviews")]
public sealed class ReviewsController(
    SupportDbContext db,
    ISender sender) : ControllerBase
{
    /// <summary>Khách hàng tạo đánh giá cho một booking đã hoàn thành.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReviewRequest req, CancellationToken ct)
    {
        var result = await sender.Send(new CreateReviewCommand(req.BookingId,
            req.CaregiverId, req.Rating, req.Comment, req.ExperienceTags), ct);
        return result.ToActionResult(this,
            review => Created($"/api/v1/reviews/{review.Id}", review));
    }

    /// <summary>Lấy danh sách các đánh giá của một caregiver.</summary>
    [HttpGet("caregiver/{caregiverId:guid}")]
    public async Task<IActionResult> GetCaregiverReviews(Guid caregiverId,
        int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var query = db.Reviews.AsNoTracking().Where(x => x.CaregiverId == caregiverId);
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return Ok(new
        {
            items = items.Select(r => new ReviewResponse(r.Id, r.BookingId, r.CaregiverId,
                r.CustomerId, r.Rating, r.Comment, r.ExperienceTags, r.CreatedAt)),
            total, page, pageSize
        });
    }

}

public sealed record CreateReviewRequest(Guid BookingId, Guid CaregiverId, int Rating,
    string? Comment = null, string? ExperienceTags = null);
