using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.MarkAllNotificationsRead;
using CareSitter.Modules.Support.Application.Commands.MarkNotificationRead;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Support.Controllers;

/// <summary>
/// Quản lý thông báo trong ứng dụng cho người dùng.
/// </summary>
[ApiController]
[Authorize]
[Route("api/v1/notifications")]
public sealed class NotificationsController(ISender sender) : ControllerBase
{
    /// <summary>Lấy danh sách thông báo của người dùng (phân trang).</summary>
    [HttpGet]
    public async Task<IActionResult> List(int page = 1, int pageSize = 20, CancellationToken ct = default)
    {
        var result = await sender.Send(new ListNotificationsQuery(page, pageSize), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Đánh dấu một thông báo là đã đọc.</summary>
    [HttpPut("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var result = await sender.Send(new MarkNotificationReadCommand(id), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Đánh dấu tất cả thông báo của người dùng là đã đọc.</summary>
    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        var result = await sender.Send(new MarkAllNotificationsReadCommand(), ct);
        return result.ToActionResult(this);
    }

    /// <summary>Lấy số lượng thông báo chưa đọc.</summary>
    [HttpGet("unread-count")]
    public async Task<IActionResult> GetUnreadCount(CancellationToken ct)
    {
        var result = await sender.Send(new GetUnreadNotificationCountQuery(), ct);
        return result.ToActionResult(this);
    }
}
