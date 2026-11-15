using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class IdentityStore(IdentityDbContext db) : IIdentityStore
{
    public Task<User?> FindUserByIdAsync(Guid userId, CancellationToken ct = default) =>
        db.Users.SingleOrDefaultAsync(x => x.Id == userId && x.DeletedAt == null, ct);

    public Task<User?> FindUserByEmailAsync(string email, CancellationToken ct = default) =>
        db.Users.FirstOrDefaultAsync(x => x.Email == email, ct);

    public Task<User?> FindUserByIdentifierAsync(
        string email, string rawIdentifier, CancellationToken ct = default) =>
        db.Users.FirstOrDefaultAsync(
            x => x.Email == email || (x.Phone != null && x.Phone == rawIdentifier), ct);

    public async Task<User?> FindUserByGoogleIdOrEmailAsync(
        string googleId, string email, CancellationToken ct = default) =>
        await db.Users.FirstOrDefaultAsync(x => x.GoogleId == googleId, ct)
        ?? await db.Users.FirstOrDefaultAsync(x => x.Email == email, ct);

    public Task<bool> EmailExistsAsync(
        string email, Guid? exceptUserId = null, CancellationToken ct = default) =>
        db.Users.AnyAsync(x => x.DeletedAt == null && x.Email == email &&
            (!exceptUserId.HasValue || x.Id != exceptUserId.Value), ct);

    public Task<bool> PhoneExistsAsync(string phone, CancellationToken ct = default) =>
        db.Users.AnyAsync(x => x.DeletedAt == null && x.Phone == phone, ct);

    public Task<int> CountActiveAdminsAsync(CancellationToken ct = default) =>
        db.Users.CountAsync(x => x.DeletedAt == null && x.Status == "ACTIVE" &&
            x.Roles.Contains("ADMIN"), ct);

    public async Task<IdentityPage<AdminUserResponse>> ListUsersAsync(
        string? query, string? role, string? status, int page, int pageSize,
        CancellationToken ct = default)
    {
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
            var normalized = role.Trim().ToUpperInvariant();
            users = users.Where(x => x.Roles.Contains(normalized));
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            var normalized = status.Trim().ToUpperInvariant();
            users = users.Where(x => x.Status == normalized);
        }

        var total = await users.CountAsync(ct);
        var entities = await users.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize).Take(pageSize).ToListAsync(ct);
        return new IdentityPage<AdminUserResponse>(
            entities.Select(ToAdminResponse).ToArray(), total, page, pageSize);
    }

    public async Task<AdminUserResponse?> GetUserResponseAsync(
        Guid userId, CancellationToken ct = default)
    {
        var user = await db.Users.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == userId && x.DeletedAt == null, ct);
        return user is null ? null : ToAdminResponse(user);
    }

    public void AddUser(User user) => db.Users.Add(user);

    public async Task SaveChangesAsync(CancellationToken ct = default)
    {
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateConcurrencyException) { throw new AuthenticationStateChangedException(); }
    }

    internal static AdminUserResponse ToAdminResponse(User user) => new(
        user.Id, user.Email, user.Phone, user.DisplayName, user.FullName, user.AvatarUrl,
        user.Status, user.Roles, user.AdminDepartment, user.AdminRole, user.AdminIsActive,
        user.LastLoginAt, user.CreatedAt, user.UpdatedAt);
}

internal sealed class IdentityDeviceStore(IdentityDbContext db) : IIdentityDeviceStore
{
    public Task<UserDevice?> FindByPushTokenAsync(string pushToken, CancellationToken ct = default) =>
        db.UserDevices.FirstOrDefaultAsync(x => x.PushToken == pushToken, ct);

    public Task<UserDevice?> FindByUserAndPlatformAsync(
        Guid userId, string platform, CancellationToken ct = default) =>
        db.UserDevices.FirstOrDefaultAsync(
            x => x.UserId == userId && x.Platform == platform, ct);

    public Task<UserDevice?> FindOwnedAsync(
        Guid deviceId, Guid userId, CancellationToken ct = default) =>
        db.UserDevices.SingleOrDefaultAsync(x => x.Id == deviceId && x.UserId == userId, ct);

    public async Task<IReadOnlyList<DeviceResponse>> ListByUserAsync(
        Guid userId, CancellationToken ct = default) =>
        await db.UserDevices.AsNoTracking().Where(x => x.UserId == userId)
            .OrderByDescending(x => x.LastSeenAt)
            .Select(x => new DeviceResponse(x.Id, x.Platform, x.DeviceName,
                x.PushToken != null, x.BiometricEnabled, x.LastSeenAt, x.CreatedAt))
            .ToListAsync(ct);

    public void Add(UserDevice device) => db.UserDevices.Add(device);
    public void Remove(UserDevice device) => db.UserDevices.Remove(device);
    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);
}
