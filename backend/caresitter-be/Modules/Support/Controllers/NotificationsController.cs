using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý thông báo trong ứng dụng cho người dùng.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/notifications")]
public sealed class NotificationsController(SupportDbContext db, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Lấy danh sách thông báo của người dùng (phân trang).</summary>
    [HttpGet]
    public async Task<IActionResult> List(int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);
        var query = db.Notifications.AsNoTracking().Where(x => x.UserId == userId);
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return Ok(new
        {
            items = items.Select(n => new NotificationResponse(n.Id, n.Type, n.Title,
                n.Body, n.Data, n.ReadAt, n.CreatedAt)),
            total, page, pageSize
        });
    }

    /// <summary>Đánh dấu một thông báo là đã đọc.</summary>
    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var n = await db.Notifications.SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (n is null) return NotFound();
        n.MarkRead();
        await db.SaveChangesAsync(ct);
        return Ok(new NotificationResponse(n.Id, n.Type, n.Title,
            n.Body, n.Data, n.ReadAt, n.CreatedAt));
    }

    /// <summary>Đánh dấu tất cả thông báo của người dùng là đã đọc.</summary>
    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var unread = await db.Notifications
            .Where(x => x.UserId == userId && x.ReadAt == null)
            .ToListAsync(ct);
        foreach (var n in unread) n.MarkRead();
        await db.SaveChangesAsync(ct);
        return Ok(new { marked = unread.Count });
    }

    /// <summary>Lấy số lượng thông báo chưa đọc.</summary>
    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount(CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return Unauthorized();
        var count = await db.Notifications.CountAsync(
            x => x.UserId == userId && x.ReadAt == null, ct);
        return Ok(new { unread = count });
    }
}

public sealed record NotificationResponse(Guid Id, string Type, string Title,
    string? Body, string? Data, DateTimeOffset? ReadAt, DateTimeOffset CreatedAt);
