using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.SharedKernel.Results;
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
public sealed class ReviewsController(SupportDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Khách hàng tạo đánh giá cho một booking đã hoàn thành.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReviewRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();

        bool exists = await db.Reviews.AnyAsync(x => x.BookingId == req.BookingId, ct);
        if (exists) return Conflict(new { error = "Booking nay da co review." });

        var created = Review.Create(req.BookingId, req.CaregiverId, userId, req.Rating,
            req.Comment, req.ExperienceTags);
        if (created.IsFailure) return Problem(created.Error);

        db.Reviews.Add(created.Value);
        await db.SaveChangesAsync(ct);
        var r = created.Value;
        return Created($"/api/v1/reviews/{r.Id}",
            new ReviewResponse(r.Id, r.BookingId, r.CaregiverId, r.CustomerId,
                r.Rating, r.Comment, r.ExperienceTags, r.CreatedAt));
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

    private IActionResult Problem(Error error) => error.Type switch
    {
        ErrorType.Conflict => Conflict(new ProblemDetails { Title = error.Code, Detail = error.Message }),
        _ => BadRequest(new ProblemDetails { Title = error.Code, Detail = error.Message })
    };
}

public sealed record CreateReviewRequest(Guid BookingId, Guid CaregiverId, int Rating,
    string? Comment = null, string? ExperienceTags = null);
public sealed record ReviewResponse(Guid Id, Guid BookingId, Guid CaregiverId, Guid CustomerId,
    int Rating, string? Comment, string? ExperienceTags, DateTimeOffset CreatedAt);
