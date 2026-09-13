using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Controllers;

/// <summary>
/// Device token endpoints: đăng ký/cập nhật FCM push token, xóa thiết bị.
/// </summary>
[ApiController]
[Route("api/v1/auth/devices")]
[Authorize]
public sealed class DeviceController : ControllerBase
{
    private readonly IdentityDbContext _db;
    private readonly ICurrentUser _currentUser;

    public DeviceController(IdentityDbContext db, ICurrentUser currentUser)
    {
        _db = db;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Đăng ký hoặc cập nhật FCM token (upsert theo userId + platform).
    /// Nếu đã có thiết bị cùng platform, cập nhật push token thay vì tạo mới.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(DeviceResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(DeviceResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RegisterDevice([FromBody] RegisterDeviceRequest req,
        CancellationToken ct)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();

        var platform = req.Platform.Trim().ToUpper();

        var pushToken = string.IsNullOrWhiteSpace(req.PushToken)
            ? null
            : req.PushToken.Trim();

        // Một FCM token chỉ được thuộc một tài khoản. Khi cùng thiết bị đăng
        // nhập tài khoản mới, gỡ token khỏi owner cũ trước khi upsert.
        UserDevice? tokenOwner = null;
        if (pushToken is not null)
        {
            tokenOwner = await _db.UserDevices
                .FirstOrDefaultAsync(x => x.PushToken == pushToken, ct);
            if (tokenOwner is not null && tokenOwner.UserId != userId)
            {
                _db.UserDevices.Remove(tokenOwner);
                tokenOwner = null;
            }
        }

        // Upsert theo user + platform cho phiên đăng nhập hiện tại.
        var existing = await _db.UserDevices
            .FirstOrDefaultAsync(x => x.UserId == userId && x.Platform == platform, ct);

        if (existing is not null)
        {
            existing.UpdatePushToken(pushToken);
            if (req.DeviceName is not null) existing.UpdateDeviceName(req.DeviceName);
            await _db.SaveChangesAsync(ct);
            return Ok(ToResponse(existing));
        }

        // Tạo thiết bị mới
        var device = UserDevice.Create(userId, platform);
        if (device.IsFailure)
            return BadRequest(new ProblemDetails
            {
                Title = device.Error.Code,
                Detail = device.Error.Message
            });

        device.Value.UpdatePushToken(pushToken);
        if (req.DeviceName is not null) device.Value.UpdateDeviceName(req.DeviceName);

        _db.UserDevices.Add(device.Value);
        await _db.SaveChangesAsync(ct);
        return Created($"/api/v1/auth/devices/{device.Value.Id}", ToResponse(device.Value));
    }

    /// <summary>
    /// Xem danh sách thiết bị của mình.
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(List<DeviceResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ListMyDevices(CancellationToken ct)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();

        // Server-side projection — no N+1
        var devices = await _db.UserDevices.AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.LastSeenAt)
            .Select(x => new DeviceResponse(x.Id, x.Platform, x.DeviceName,
                x.PushToken != null, x.BiometricEnabled, x.LastSeenAt, x.CreatedAt))
            .ToListAsync(ct);

        return Ok(devices);
    }

    /// <summary>
    /// Xóa 1 thiết bị (khi logout hoặc hủy đăng ký push).
    /// </summary>
    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteDevice(Guid id, CancellationToken ct)
    {
        if (_currentUser.UserId is not { } userId) return Unauthorized();

        var device = await _db.UserDevices
            .SingleOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (device is null) return NotFound();

        _db.UserDevices.Remove(device);
        await _db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static DeviceResponse ToResponse(UserDevice d) => new(d.Id, d.Platform,
        d.DeviceName, d.PushToken is not null, d.BiometricEnabled, d.LastSeenAt, d.CreatedAt);
}

// ── DTOs ──
public sealed record RegisterDeviceRequest(string Platform, string? PushToken = null,
    string? DeviceName = null);
public sealed record DeviceResponse(Guid Id, string Platform, string? DeviceName,
    bool HasPushToken, bool BiometricEnabled, DateTimeOffset? LastSeenAt, DateTimeOffset CreatedAt);
