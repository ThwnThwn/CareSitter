using System.Text.Json;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/users")]
public sealed class AdminUsersController(
    IdentityDbContext db,
    ICurrentUser currentUser) : ControllerBase
{
    private static readonly string[] AllowedRoles = ["CUSTOMER", "CAREGIVER", "ADMIN"];

    [HttpGet]
    public async Task<IActionResult> List(
        string? query = null,
        string? role = null,
        string? status = null,
        int page = 1,
        int pageSize = 20,
        CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 50);

        var users = db.Users.AsNoTracking().Where(x => x.DeletedAt == null);
        if (!string.IsNullOrWhiteSpace(query))
        {
            var term = $"%{query.Trim()}%";
            users = users.Where(x => EF.Functions.ILike(x.Email, term)
                || (x.Phone != null && EF.Functions.ILike(x.Phone, term))
                || (x.DisplayName != null && EF.Functions.ILike(x.DisplayName, term))
                || (x.FullName != null && EF.Functions.ILike(x.FullName, term)));
        }
        if (!string.IsNullOrWhiteSpace(role))
        {
            var normalizedRole = role.Trim().ToUpperInvariant();
            users = users.Where(x => x.Roles.Contains(normalizedRole));
        }
        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalizedStatus = status.Trim().ToUpperInvariant();
            users = users.Where(x => x.Status == normalizedStatus);
        }

        var total = await users.CountAsync(ct);
        var entities = await users.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(ct);

        return Ok(new { items = entities.Select(ToResponse), total, page, pageSize });
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var user = await db.Users.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        return user is null ? NotFound() : Ok(ToResponse(user));
    }

    [HttpPatch("{id:guid}/status")]
    public async Task<IActionResult> SetStatus(Guid id, [FromBody] AdminUserStatusRequest request,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } adminId) return Unauthorized();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        if (user is null) return NotFound();

        var normalizedStatus = request.Status?.Trim().ToUpperInvariant();
        if (id == adminId && normalizedStatus != "ACTIVE")
            return Conflict(new { error = "Bạn không thể khóa hoặc tạm ngưng chính tài khoản đang đăng nhập." });

        if (user.Roles.Contains("ADMIN") && user.Status == "ACTIVE" && normalizedStatus != "ACTIVE"
            && await ActiveAdminCount(ct) <= 1)
            return Conflict(new { error = "Hệ thống phải còn ít nhất một tài khoản ADMIN đang hoạt động." });

        var before = JsonSerializer.Serialize(new { user.Status });
        var result = user.SetStatus(normalizedStatus ?? string.Empty);
        if (result.IsFailure) return BadRequest(new { error = result.Error.Message });

        AddAudit(adminId, "ADMIN_USER_STATUS_UPDATED", user.Id, before,
            JsonSerializer.Serialize(new { user.Status }));
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(user));
    }

    [HttpPut("{id:guid}/roles")]
    public async Task<IActionResult> SetRoles(Guid id, [FromBody] AdminUserRolesRequest request,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } adminId) return Unauthorized();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);
        if (user is null) return NotFound();

        var roles = (request.Roles ?? [])
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x.Trim().ToUpperInvariant())
            .Distinct()
            .ToArray();
        if (roles.Length == 0 || roles.Any(x => !AllowedRoles.Contains(x)))
            return BadRequest(new { error = "Vai trò phải gồm CUSTOMER, CAREGIVER hoặc ADMIN." });
        if (id == adminId && !roles.Contains("ADMIN"))
            return Conflict(new { error = "Bạn không thể tự gỡ quyền ADMIN của tài khoản đang đăng nhập." });
        if (user.Roles.Contains("ADMIN") && !roles.Contains("ADMIN") && user.Status == "ACTIVE"
            && await ActiveAdminCount(ct) <= 1)
            return Conflict(new { error = "Hệ thống phải còn ít nhất một tài khoản ADMIN đang hoạt động." });

        var before = JsonSerializer.Serialize(new { user.Roles });
        user.SetRoles(roles);
        AddAudit(adminId, "ADMIN_USER_ROLES_UPDATED", user.Id, before,
            JsonSerializer.Serialize(new { user.Roles }));
        await db.SaveChangesAsync(ct);
        return Ok(ToResponse(user));
    }

    private Task<int> ActiveAdminCount(CancellationToken ct) => db.Users.CountAsync(x =>
        x.DeletedAt == null && x.Status == "ACTIVE" && x.Roles.Contains("ADMIN"), ct);

    private void AddAudit(Guid actorId, string action, Guid entityId, string before, string after)
    {
        var result = AuditLog.Create(action, "User", actorId, entityId, after,
            HttpContext.Connection.RemoteIpAddress?.ToString(), Request.Headers.UserAgent.ToString());
        if (result.IsSuccess)
        {
            var entry = result.Value;
            db.AuditLogs.Add(entry);
            db.Entry(entry).Property(x => x.BeforeData).CurrentValue = before;
        }
    }

    private static object ToResponse(User x) => new
    {
        x.Id,
        x.Email,
        x.Phone,
        x.DisplayName,
        x.FullName,
        x.AvatarUrl,
        x.Status,
        x.Roles,
        x.AdminDepartment,
        x.AdminRole,
        x.AdminIsActive,
        x.LastLoginAt,
        x.CreatedAt,
        x.UpdatedAt
    };
}

public sealed record AdminUserStatusRequest(string Status);
public sealed record AdminUserRolesRequest(string[]? Roles);
