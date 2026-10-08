using System.Diagnostics;
using System.Net.Mail;
using System.Security.Cryptography;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.Modules.Identity.Infrastructure;

internal sealed class PasswordRecoveryService(IdentityDbContext db, IPasswordHasher hasher,
    IClock clock, IOptions<RecoveryOptions> options, RecoverySecrets secrets,
    RealtimeSessionRegistry? realtime = null) : IPasswordRecoveryService
{
    private RecoveryOptions Settings => options.Value;
    private static Error InvalidCode() => Error.Validation("recovery.invalid_code", "Mã không hợp lệ, đã dùng hoặc hết hạn. Vui lòng yêu cầu mã mới.");
    private static Error InvalidGrant() => Error.Validation("recovery.invalid_token", "Yêu cầu đặt mật khẩu đã dùng hoặc hết hạn. Vui lòng bắt đầu lại.");
    private static Error Unavailable() => Error.Unavailable("recovery.unavailable", "Khôi phục mật khẩu chưa sẵn sàng. Vui lòng thử đăng nhập bằng mã email.");
    private static bool Eligible(User? user) => user is { Status: "ACTIVE", DeletedAt: null, PasswordHash: not null, EmailVerifiedAt: not null }
        && !user.Roles.Contains("ADMIN") && user.Roles.Any(x => x is "CUSTOMER" or "CAREGIVER");
    private static bool ValidEmail(string email) => email.Length <= 255 && MailAddress.TryCreate(email, out var parsed)
        && string.Equals(parsed.Address, email, StringComparison.OrdinalIgnoreCase);

    public async Task<Result<RecoveryChallengeResponse>> RequestAsync(string email, CancellationToken ct)
    {
        if (!Settings.Enabled) return Unavailable();
        email = email?.Trim().ToLowerInvariant() ?? string.Empty;
        if (!ValidEmail(email)) return Error.Validation("recovery.email", "Vui lòng nhập email hợp lệ.");
        var timer = Stopwatch.StartNew();
        var minimumDelay = TimeSpan.FromMilliseconds(250 + RandomNumberGenerator.GetInt32(0, 100));
        try
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var rateKey = secrets.Digest($"request:RESET:{email}");
            var limit = await LimitAsync(rateKey, ct);
            if (limit.IsFailure) return limit.Error;
            var found = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Email == email && x.DeletedAt == null, ct);
            var user = found is null ? null : await LockUserAsync(found.Id, ct);
            var valid = Eligible(user);
            var now = clock.UtcNow;
            await db.RecoveryChallenges.Where(x => x.RateKey == rateKey && x.ConsumedAt == null)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAt, now), ct);
            var result = AddChallenge(valid ? user : null, "RESET", email, email, rateKey);
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            return result;
        }
        finally
        {
            var delay = minimumDelay - timer.Elapsed;
            if (delay > TimeSpan.Zero) await Task.Delay(delay, ct);
        }
    }

    public async Task<Result<RecoveryGrantResponse>> VerifyAsync(Guid challengeId, string code, CancellationToken ct)
    {
        if (!Settings.Enabled) return Unavailable();
        var found = await db.RecoveryChallenges.AsNoTracking().SingleOrDefaultAsync(x => x.Id == challengeId && x.Purpose == "RESET", ct);
        if (found?.UserId is not { } userId) return InvalidCode();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var user = await LockUserAsync(userId, ct);
        var challenge = await LockChallengeAsync(challengeId, ct);
        if (challenge is null || !Eligible(user) || !Bound(challenge, user!)) return InvalidCode();
        if (!CheckCode(challenge, code))
        {
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return InvalidCode();
        }
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        challenge.CodeConsumedAt = clock.UtcNow;
        challenge.GrantHash = RecoverySecrets.TokenHash(token);
        challenge.GrantExpiresAt = clock.UtcNow.AddMinutes(Settings.GrantMinutes);
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return new RecoveryGrantResponse(token, Settings.GrantMinutes * 60);
    }

    public async Task<Result> ResetAsync(string token, string newPassword, CancellationToken ct)
    {
        if (!Settings.Enabled) return Unavailable();
        var policy = PasswordPolicy.Validate(newPassword); if (policy.IsFailure) return policy;
        if (string.IsNullOrWhiteSpace(token) || token.Length != 64) return InvalidGrant();
        var hash = RecoverySecrets.TokenHash(token);
        var found = await db.RecoveryChallenges.AsNoTracking().SingleOrDefaultAsync(x => x.GrantHash == hash && x.Purpose == "RESET", ct);
        if (found?.UserId is not { } userId) return InvalidGrant();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var user = await LockUserAsync(userId, ct);
        var grant = await LockChallengeAsync(found.Id, ct);
        if (grant is null || !Eligible(user) || !Bound(grant, user!) || grant.ConsumedAt is not null ||
            grant.CodeConsumedAt is null || grant.GrantHash != hash || grant.GrantExpiresAt <= clock.UtcNow)
            return InvalidGrant();
        if (hasher.Verify(newPassword, user!.PasswordHash))
            return Error.Validation("password.same", "Mật khẩu mới phải khác mật khẩu hiện tại.");
        user.SetPassword(hasher.Hash(newPassword));
        await InvalidateAsync(userId, ct);
        AddAudit(userId, "PASSWORD_RECOVERY_COMPLETED");
        AddMail(null, user.Email, "Mật khẩu CareSitter đã thay đổi",
            CareSitterEmailTemplate.Notification("Mật khẩu đã thay đổi",
                "Mật khẩu của bạn đã được đặt lại. Mọi phiên cũ đã bị thu hồi. Hãy đăng nhập lại. Nếu bạn không thực hiện thao tác này, hãy liên hệ đơn vị hỗ trợ CareSitter."));
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        realtime?.DisconnectUser(userId);
        return Result.Success();
    }

    public async Task<Result<RecoveryChallengeResponse>> RequestEmailAsync(Guid userId, string? newEmail, string? currentPassword, CancellationToken ct)
    {
        if (!Settings.Enabled) return Unavailable();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var user = await LockUserAsync(userId, ct);
        if (user is null || user.Status != "ACTIVE" || user.DeletedAt is not null) return Error.Unauthorized("auth.required", "Vui lòng đăng nhập lại.");
        var email = string.IsNullOrWhiteSpace(newEmail) ? user.Email : newEmail.Trim().ToLowerInvariant();
        if (!ValidEmail(email)) return Error.Validation("recovery.email", "Vui lòng nhập email hợp lệ.");
        var changing = email != user.Email;
        var rateKey = secrets.Digest($"request:PROFILE:{userId:D}");
        var limit = await LimitAsync(rateKey, ct); if (limit.IsFailure) return limit.Error;
        if (changing && (user.PasswordHash is null || !hasher.Verify(currentPassword ?? string.Empty, user.PasswordHash)))
        {
            AddChallenge(null, "CHANGE_EMAIL", user.Email, email, rateKey);
            await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
            return Error.Validation("email.reauthentication", "Đổi email cần mật khẩu hiện tại. Tài khoản chỉ dùng Google/OTP cần liên hệ hỗ trợ để đổi email.");
        }
        if (changing && await db.Users.AnyAsync(x => x.Email == email && x.Id != userId && x.DeletedAt == null, ct))
            return Error.Conflict("email.exists", "Email đã được sử dụng.");
        var purpose = changing ? "CHANGE_EMAIL" : "VERIFY_EMAIL";
        var now = clock.UtcNow;
        await db.RecoveryChallenges.Where(x => x.UserId == userId && x.Purpose != "RESET" && x.ConsumedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAt, now), ct);
        var result = AddChallenge(user, purpose, user.Email, email, rateKey);
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        return result;
    }

    public async Task<Result<RecoveryEmailResponse>> ConfirmEmailAsync(Guid userId, Guid challengeId, string code, CancellationToken ct)
    {
        if (!Settings.Enabled) return Unavailable();
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var user = await LockUserAsync(userId, ct);
        var challenge = await LockChallengeAsync(challengeId, ct);
        if (user is null || user.Status != "ACTIVE" || user.DeletedAt is not null || challenge is null ||
            challenge.UserId != userId || challenge.Purpose is not ("VERIFY_EMAIL" or "CHANGE_EMAIL") || !Bound(challenge, user))
            return InvalidCode();
        if (!CheckCode(challenge, code))
        { await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); return InvalidCode(); }
        var changing = challenge.Purpose == "CHANGE_EMAIL";
        if (changing)
        {
            if (await db.Users.AnyAsync(x => x.Email == challenge.TargetEmail && x.Id != userId && x.DeletedAt == null, ct))
                return Error.Conflict("email.exists", "Email đã được sử dụng.");
            if (user.EmailVerifiedAt is not null)
                AddMail(null, user.Email, "Email CareSitter đã thay đổi",
                    CareSitterEmailTemplate.Notification("Email đã thay đổi",
                        "Email đăng nhập và khôi phục đã được thay đổi. Nếu bạn không thực hiện, hãy liên hệ đơn vị hỗ trợ CareSitter."));
            user.ChangeEmail(challenge.TargetEmail);
            await InvalidateAsync(userId, ct);
        }
        user.VerifyEmail(clock.UtcNow); challenge.ConsumedAt = clock.UtcNow;
        challenge.CodeConsumedAt = clock.UtcNow;
        AddAudit(userId, changing ? "RECOVERY_EMAIL_CHANGED" : "RECOVERY_EMAIL_VERIFIED");
        try { await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); }
        catch (DbUpdateException e) when (e.InnerException is PostgresException { SqlState: "23505" })
        { return Error.Conflict("email.exists", "Email đã được sử dụng."); }
        if (changing) realtime?.DisconnectUser(userId);
        return new RecoveryEmailResponse(user.Email, user.EmailVerifiedAt!.Value, changing);
    }

    public async Task<Result<string>> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword, CancellationToken ct)
    {
        var policy = PasswordPolicy.Validate(newPassword); if (policy.IsFailure) return policy.Error;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var user = await LockUserAsync(userId, ct);
        if (user is null || user.Status != "ACTIVE" || user.DeletedAt is not null) return Error.Unauthorized("auth.required", "Vui lòng đăng nhập lại.");
        if (user.PasswordHash is null || !hasher.Verify(currentPassword ?? string.Empty, user.PasswordHash))
            return Error.Validation("password.incorrect", "Mật khẩu hiện tại không chính xác.");
        if (hasher.Verify(newPassword, user.PasswordHash)) return Error.Validation("password.same", "Mật khẩu mới phải khác mật khẩu hiện tại.");
        user.SetPassword(hasher.Hash(newPassword));
        await InvalidateAsync(userId, ct); AddAudit(userId, "PASSWORD_CHANGED");
        if (Settings.Enabled && user.EmailVerifiedAt is not null)
            AddMail(null, user.Email, "Mật khẩu CareSitter đã thay đổi",
                CareSitterEmailTemplate.Notification("Mật khẩu đã thay đổi",
                    "Mật khẩu đã được thay đổi. Mọi phiên cũ đã bị thu hồi. Hãy đăng nhập lại."));
        await db.SaveChangesAsync(ct); await tx.CommitAsync(ct);
        realtime?.DisconnectUser(userId);
        return "Đổi mật khẩu thành công. Vui lòng đăng nhập lại.";
    }

    private Task<User?> LockUserAsync(Guid id, CancellationToken ct) => db.Users
        .FromSqlInterpolated($"SELECT * FROM identity.users WHERE id = {id} FOR UPDATE").SingleOrDefaultAsync(ct);
    private Task<RecoveryChallengeRecord?> LockChallengeAsync(Guid id, CancellationToken ct) => db.RecoveryChallenges
        .FromSqlInterpolated($"SELECT * FROM identity.recovery_challenges WHERE id = {id} FOR UPDATE").SingleOrDefaultAsync(ct);
    private bool Bound(RecoveryChallengeRecord record, User user) => record.Email == user.Email && record.RecoveryVersion == user.RecoveryVersion;
    private bool CheckCode(RecoveryChallengeRecord record, string code)
    {
        if (record.ConsumedAt is not null || record.CodeConsumedAt is not null || record.ExpiresAt <= clock.UtcNow || record.Attempts >= Settings.MaxAttempts) return false;
        record.Attempts++;
        var matches = code is { Length: 6 } && code.All(char.IsAsciiDigit) && secrets.Matches(record.Id, code, record.CodeHash);
        if (!matches && record.Attempts >= Settings.MaxAttempts) record.ConsumedAt = clock.UtcNow;
        return matches;
    }
    private async Task<Result> LimitAsync(string rateKey, CancellationToken ct)
    {
        await db.Database.ExecuteSqlInterpolatedAsync($"SELECT pg_advisory_xact_lock(hashtextextended({rateKey}, 0))", ct);
        var recent = db.RecoveryChallenges.Where(x => x.RateKey == rateKey && x.CreatedAt > clock.UtcNow.AddHours(-1));
        if (await recent.CountAsync(ct) >= Settings.RequestsPerHour || await recent.AnyAsync(x => x.CreatedAt > clock.UtcNow.AddSeconds(-Settings.ResendSeconds), ct))
            return Error.Conflict("recovery.rate_limit", $"Vui lòng chờ trước khi yêu cầu mã mới. Tối đa {Settings.RequestsPerHour} yêu cầu mỗi giờ.");
        return Result.Success();
    }
    private RecoveryChallengeResponse AddChallenge(User? user, string purpose, string email, string target, string rateKey)
    {
        var id = Guid.NewGuid(); var code = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var record = new RecoveryChallengeRecord { Id = id, UserId = user?.Id, Purpose = purpose, Email = email, TargetEmail = target,
            RateKey = rateKey, RecoveryVersion = user?.RecoveryVersion ?? 0, CodeHash = secrets.CodeHash(id, code),
            CreatedAt = clock.UtcNow, ExpiresAt = clock.UtcNow.AddMinutes(Settings.CodeMinutes) };
        db.RecoveryChallenges.Add(record);
        var task = purpose == "RESET" ? "khôi phục mật khẩu" : "xác minh email";
        AddMail(id, user is null ? null : target, $"Mã {task} CareSitter",
            CareSitterEmailTemplate.Code(
                purpose == "RESET" ? "Khôi phục mật khẩu" : "Xác minh email",
                $"Đây là mã để {task} cho tài khoản CareSitter của bạn.",
                code, Settings.CodeMinutes), record.ExpiresAt);
        return new RecoveryChallengeResponse(id, Settings.CodeMinutes * 60, Settings.ResendSeconds,
            "Nếu tài khoản đủ điều kiện, mã xác minh sẽ được gửi tới email này.");
    }
    private void AddMail(Guid? challengeId, string? recipient, string subject, string body, DateTimeOffset? expiresAt = null)
        => db.RecoveryEmails.Add(new RecoveryEmailRecord { Id = Guid.NewGuid(), ChallengeId = challengeId,
            Payload = secrets.Encrypt(new RecoveryMail(recipient, subject, body)), CreatedAt = clock.UtcNow,
            ExpiresAt = expiresAt ?? clock.UtcNow.AddDays(1), NextAttemptAt = clock.UtcNow });
    private async Task InvalidateAsync(Guid userId, CancellationToken ct)
    {
        var now = clock.UtcNow;
        await db.RefreshTokenSessions.Where(x => x.UserId == userId && x.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.RevokedAt, now), ct);
        await db.RecoveryChallenges.Where(x => x.UserId == userId && x.ConsumedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.ConsumedAt, now), ct);
    }
    private void AddAudit(Guid userId, string action)
    {
        var result = AuditLog.Create(action, "USER", actorUserId: userId, entityId: userId);
        if (result.IsSuccess) db.AuditLogs.Add(result.Value);
    }
}
