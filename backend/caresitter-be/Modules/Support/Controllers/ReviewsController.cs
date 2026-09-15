using CareSitter.Contracts.Services;
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
public sealed class ReviewsController(
    SupportDbContext db,
    ICurrentUser currentUser,
    IReviewBookingLookup bookingLookup) : ControllerBase
{
    /// <summary>Khách hàng tạo đánh giá cho một booking đã hoàn thành.</summary>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateReviewRequest req, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        if (req.BookingId == Guid.Empty || req.CaregiverId == Guid.Empty)
            return BadRequest(new { error = "Booking và caregiver là bắt buộc." });

        var comment = req.Comment?.Trim();
        var experienceTags = req.ExperienceTags?.Trim();
        if (comment?.Length > 1_000)
            return BadRequest(new { error = "Nội dung đánh giá không được vượt quá 1000 ký tự." });
        if (experienceTags?.Length > 1_000)
            return BadRequest(new { error = "Danh sách trải nghiệm không được vượt quá 1000 ký tự." });

        var booking = await bookingLookup.GetForReviewAsync(req.BookingId, ct);
        if (booking is null) return NotFound(new { error = "Không tìm thấy booking." });
        if (booking.CustomerId != userId) return Forbid();
        if (!booking.IsCompleted)
            return Conflict(new { error = "Chỉ có thể đánh giá sau khi ca chăm sóc hoàn tất." });
        if (booking.CaregiverId != req.CaregiverId)
            return BadRequest(new { error = "Caregiver không khớp với booking này." });

        bool exists = await db.Reviews.AnyAsync(x => x.BookingId == req.BookingId, ct);
        if (exists) return Conflict(new { error = "Booking nay da co review." });

        var created = Review.Create(req.BookingId, req.CaregiverId, userId, req.Rating,
            comment, experienceTags);
        if (created.IsFailure) return Problem(created.Error);

        db.Reviews.Add(created.Value);
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            // DB unique index là lớp cuối cùng khi hai request cùng gửi review.
            return Conflict(new { error = "Booking này đã có review." });
        }
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
