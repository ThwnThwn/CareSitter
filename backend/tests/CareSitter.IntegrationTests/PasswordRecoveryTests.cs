using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Text;
using System.Security.Claims;
using System.Text.RegularExpressions;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Identity;
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Controllers;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Infrastructure;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class PasswordRecoveryTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;
    private readonly TestClock _clock = new();
    private readonly IOptions<RecoveryOptions> _options = Options.Create(new RecoveryOptions
        { Enabled = true, SecretKey = "test-recovery-secret-only-more-than-32-characters" });
    private readonly BcryptPasswordHasher _hasher = new();
    private static readonly IOptions<JwtSettings> Jwt = Options.Create(new JwtSettings
    { Issuer = "Recovery.Tests", Audience = "Recovery.Client", SecretKey = "test-jwt-secret-only-more-than-32-characters", RefreshTokenExpiryDays = 7 });
    private readonly MemoryDistributedCache _cache = new(Options.Create(new MemoryDistributedCacheOptions()));
    public async Task InitializeAsync() => _database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (_database is not null) await _database.DisposeAsync(); }
    private IdentityDbContext Context() => new(new DbContextOptionsBuilder<IdentityDbContext>().UseNpgsql(_database.ConnectionString).Options);
    private RecoverySecrets Secrets => new(_options);
    private PasswordRecoveryService Recovery(IdentityDbContext db) => new(db, _hasher, _clock, _options, Secrets);
    private RefreshTokenSessionService Sessions(IdentityDbContext db) => new(db, _cache, new JwtTokenService(Jwt), Jwt,
        new HttpContextAccessor(), NullLogger<RefreshTokenSessionService>.Instance);
    private async Task<User> SeedAsync(bool verified = true, string status = "ACTIVE", string[]? roles = null, bool password = true)
    {
        var user = User.Create(Guid.NewGuid(), $"recovery-{Guid.NewGuid():N}@example.com").Value;
        user.UpdateProfile("Recovery test", user.Email, "Recovery test"); user.SetRoles(roles ?? ["CUSTOMER"]);
        user.SetStatus(status); if (password) user.SetPassword(_hasher.Hash("OldPassword123"));
        if (verified) user.VerifyEmail(_clock.UtcNow);
        await using var db = Context(); db.Users.Add(user); await db.SaveChangesAsync(); return user;
    }
    private async Task<(RecoveryChallengeResponse Challenge, string Code)> RequestAsync(User user)
    {
        await using var db = Context();
        var result = await Recovery(db).RequestAsync(user.Email, default); Assert.True(result.IsSuccess, result.Error.Message);
        var row = await db.RecoveryEmails.AsNoTracking().SingleAsync(x => x.ChallengeId == result.Value.ChallengeId);
        var code = Regex.Match(Secrets.Decrypt(row.Payload!).Html, @">(\d{6})</strong>").Groups[1].Value;
        Assert.Equal(6, code.Length); Assert.DoesNotContain(code, row.Payload!);
        return (result.Value, code);
    }
    private async Task<RecoveryGrantResponse> GrantAsync(User user)
    {
        var request = await RequestAsync(user); await using var db = Context();
        var grant = await Recovery(db).VerifyAsync(request.Challenge.ChallengeId, request.Code, default);
        Assert.True(grant.IsSuccess, grant.Error.Message); return grant.Value;
    }

    [PostgresFact]
    public async Task Http_flow_changes_password_and_rejects_all_old_access_and_refresh_sessions()
    {
        var user = await SeedAsync();
        await using var app = await ServerAsync(); var client = app.GetTestClient();
        var login = await client.PostAsJsonAsync("/api/v1/auth/login/password", new { email = user.Email, password = "OldPassword123" });
        var tokens = (await login.Content.ReadFromJsonAsync<LoginResponse>())!;
        await using (var scope = app.Services.CreateAsyncScope()) await scope.ServiceProvider.GetRequiredService<IOtpStore>()
            .SaveAsync(user.Email, "654321", TimeSpan.FromMinutes(10), TimeSpan.FromSeconds(60));
        var another = await client.PostAsJsonAsync("/api/v1/auth/login/password", new { email = user.Email, password = "OldPassword123" });
        var second = (await another.Content.ReadFromJsonAsync<LoginResponse>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.AccessToken);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/v1/profile")).StatusCode);
        var requested = await client.PostAsJsonAsync("/api/v1/auth/password-recovery/request", new { email = user.Email });
        Assert.Equal(HttpStatusCode.Accepted, requested.StatusCode);
        var challenge = (await requested.Content.ReadFromJsonAsync<RecoveryChallengeResponse>())!;
        await using var db = Context(); var mail = await db.RecoveryEmails.AsNoTracking().SingleAsync(x => x.ChallengeId == challenge.ChallengeId);
        var code = Regex.Match(Secrets.Decrypt(mail.Payload!).Html, @">(\d{6})</strong>").Groups[1].Value;
        var verified = await client.PostAsJsonAsync("/api/v1/auth/password-recovery/verify", new { challengeId = challenge.ChallengeId, code });
        var grant = (await verified.Content.ReadFromJsonAsync<RecoveryGrantResponse>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", grant.ResetToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/profile")).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.AccessToken);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/password-recovery/reset", new
            { resetToken = grant.ResetToken, newPassword = "NewPassword456", confirmPassword = "Mismatch456" })).StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsJsonAsync("/api/v1/auth/password-recovery/reset", new
            { resetToken = grant.ResetToken, newPassword = "NewPassword456", confirmPassword = "NewPassword456" })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/profile")).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", second.AccessToken);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/profile")).StatusCode);
        foreach (var refresh in new[] { tokens.RefreshToken, second.RefreshToken })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = refresh })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/login/password", new { email = user.Email, password = "OldPassword123" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/login", new { email = user.Email, otp = "654321" })).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.PostAsJsonAsync("/api/v1/auth/login/password", new { email = user.Email, password = "NewPassword456" })).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsJsonAsync("/api/v1/auth/password-recovery/reset", new
            { resetToken = grant.ResetToken, newPassword = "AgainPassword789", confirmPassword = "AgainPassword789" })).StatusCode);
        Assert.Contains(await db.AuditLogs.AsNoTracking().ToListAsync(), x => x.Action == "PASSWORD_RECOVERY_COMPLETED" && x.ActorUserId == user.Id);
    }

    [PostgresFact]
    public async Task Unknown_unverified_locked_admin_and_google_only_accounts_get_same_response_and_no_grant()
    {
        var eligible = await SeedAsync();
        var users = new[] { await SeedAsync(false), await SeedAsync(status: "LOCKED"), await SeedAsync(status: "SUSPENDED"),
            await SeedAsync(roles: ["CUSTOMER", "ADMIN"]), await SeedAsync(password: false) };
        await using var db = Context(); var recovery = Recovery(db);
        var known = await recovery.RequestAsync(eligible.Email, default);
        foreach (var email in users.Select(x => x.Email).Append("unknown@example.com"))
        {
            var result = await recovery.RequestAsync(email, default); Assert.True(result.IsSuccess);
            Assert.Equal(known.Value.Message, result.Value.Message);
            Assert.Equal(known.Value.ExpiresIn, result.Value.ExpiresIn);
            var row = await db.RecoveryChallenges.AsNoTracking().SingleAsync(x => x.Id == result.Value.ChallengeId);
            Assert.Null(row.UserId);
            var mail = Secrets.Decrypt((await db.RecoveryEmails.AsNoTracking().SingleAsync(x => x.ChallengeId == row.Id)).Payload!);
            Assert.Null(mail.Recipient);
            var code = Regex.Match(mail.Html, @">(\d{6})</strong>").Groups[1].Value;
            Assert.True((await recovery.VerifyAsync(row.Id, code, default)).IsFailure);
        }
    }

    [PostgresFact]
    public async Task Attempts_expiry_resend_and_purpose_separation_are_enforced()
    {
        var user = await SeedAsync(); var request = await RequestAsync(user);
        await using (var db = Context())
        {
            var service = Recovery(db);
            Assert.Equal("recovery.rate_limit", (await service.RequestAsync(user.Email, default)).Error.Code);
            var wrong = request.Code == "000000" ? "111111" : "000000";
            for (var i = 0; i < 5; i++) Assert.True((await service.VerifyAsync(request.Challenge.ChallengeId, wrong, default)).IsFailure);
            Assert.True((await service.VerifyAsync(request.Challenge.ChallengeId, request.Code, default)).IsFailure);
        }
        _clock.Advance(TimeSpan.FromMinutes(2)); request = await RequestAsync(user);
        _clock.Advance(TimeSpan.FromMinutes(11));
        await using (var db = Context()) Assert.True((await Recovery(db).VerifyAsync(request.Challenge.ChallengeId, request.Code, default)).IsFailure);
        var grant = await GrantAsync(user); _clock.Advance(TimeSpan.FromMinutes(6));
        await using (var db = Context()) Assert.True((await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default)).IsFailure);
        await using (var db = Context())
        {
            var service = Recovery(db); var email = await service.RequestEmailAsync(user.Id, null, null, default);
            var outbox = await db.RecoveryEmails.AsNoTracking().SingleAsync(x => x.ChallengeId == email.Value.ChallengeId);
            var code = Regex.Match(Secrets.Decrypt(outbox.Payload!).Html, @">(\d{6})</strong>").Groups[1].Value;
            Assert.True((await service.VerifyAsync(email.Value.ChallengeId, code, default)).IsFailure);
        }
    }

    [PostgresFact]
    public async Task Concurrent_verification_and_reset_have_one_winner()
    {
        var user = await SeedAsync(); var request = await RequestAsync(user);
        var grants = await Task.WhenAll(Enumerable.Range(0, 2).Select(async _ =>
        { await using var db = Context(); return await Recovery(db).VerifyAsync(request.Challenge.ChallengeId, request.Code, default); }));
        var grant = Assert.Single(grants, x => x.IsSuccess).Value;
        var resets = await Task.WhenAll(Enumerable.Range(0, 2).Select(async _ =>
        { await using var db = Context(); return await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default); }));
        Assert.Single(resets, x => x.IsSuccess);
        await using var verify = Context(); Assert.Equal(1, await verify.AuditLogs.CountAsync(x => x.Action == "PASSWORD_RECOVERY_COMPLETED" && x.ActorUserId == user.Id));
    }

    [PostgresFact]
    public async Task Resend_and_security_changes_invalidate_previous_grants()
    {
        var user = await SeedAsync(); var grant = await GrantAsync(user);
        _clock.Advance(TimeSpan.FromMinutes(2)); await RequestAsync(user);
        await using (var db = Context()) Assert.True((await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default)).IsFailure);
        foreach (var change in new Action<User>[] { x => x.SetPassword(_hasher.Hash("ChangedPassword123")), x => x.ChangeEmail("changed@example.com"), x => x.SetStatus("LOCKED"), x => x.SetRoles(["ADMIN"]) })
        {
            var account = await SeedAsync(); var issued = await GrantAsync(account);
            await using (var db = Context()) { var entity = await db.Users.SingleAsync(x => x.Id == account.Id); change(entity); await db.SaveChangesAsync(); }
            await using (var db = Context()) Assert.True((await Recovery(db).ResetAsync(issued.ResetToken, "NewPassword456", default)).IsFailure);
        }
    }

    [PostgresFact]
    public async Task Email_confirmation_is_owner_bound_and_changes_email_only_after_reauthentication_and_code()
    {
        var user = await SeedAsync(false); var target = $"new-{Guid.NewGuid():N}@example.com";
        await using var db = Context(); var service = Recovery(db);
        Assert.True((await service.RequestEmailAsync(user.Id, target, "wrong", default)).IsFailure);
        _clock.Advance(TimeSpan.FromMinutes(2));
        var request = await service.RequestEmailAsync(user.Id, target, "OldPassword123", default);
        Assert.True(request.IsSuccess); Assert.Equal(user.Email, (await db.Users.AsNoTracking().SingleAsync(x => x.Id == user.Id)).Email);
        var mail = await db.RecoveryEmails.AsNoTracking().SingleAsync(x => x.ChallengeId == request.Value.ChallengeId);
        var code = Regex.Match(Secrets.Decrypt(mail.Payload!).Html, @">(\d{6})</strong>").Groups[1].Value;
        Assert.True((await service.ConfirmEmailAsync(Guid.NewGuid(), request.Value.ChallengeId, code, default)).IsFailure);
        db.ChangeTracker.Clear();
        var confirmed = await service.ConfirmEmailAsync(user.Id, request.Value.ChallengeId, code, default);
        Assert.True(confirmed.IsSuccess); Assert.Equal(target, confirmed.Value.Email); Assert.True(confirmed.Value.SessionsRevoked);
        Assert.True((await service.ConfirmEmailAsync(user.Id, request.Value.ChallengeId, code, default)).IsFailure);
    }

    [PostgresFact]
    public async Task Smtp_failure_does_not_roll_back_password_and_retry_clears_encrypted_payload_after_delivery()
    {
        var user = await SeedAsync(); var grant = await GrantAsync(user);
        await using (var db = Context()) Assert.True((await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default)).IsSuccess);
        var sender = new TestSender { Fail = true };
        // The consumed code email is discarded; the notification retries independently.
        await using (var db = Context())
        {
            var dispatcher = new RecoveryEmailDispatcher(db, Secrets, sender, _clock, NullLogger<RecoveryEmailDispatcher>.Instance);
            await dispatcher.DispatchOnceAsync(default); await dispatcher.DispatchOnceAsync(default);
            Assert.True(_hasher.Verify("NewPassword456", (await db.Users.AsNoTracking().SingleAsync(x => x.Id == user.Id)).PasswordHash));
            Assert.Contains(await db.RecoveryEmails.AsNoTracking().ToListAsync(), x => x.ChallengeId == null && x.CompletedAt == null && x.Attempts == 1);
        }
        sender.Fail = false; _clock.Advance(TimeSpan.FromMinutes(1));
        await using (var db = Context())
        {
            Assert.True(await new RecoveryEmailDispatcher(db, Secrets, sender, _clock, NullLogger<RecoveryEmailDispatcher>.Instance).DispatchOnceAsync(default));
            Assert.Single(sender.Subjects);
            Assert.All(await db.RecoveryEmails.AsNoTracking().ToListAsync(), x => { Assert.Null(x.Payload); Assert.NotNull(x.CompletedAt); });
            Assert.Contains(await db.RecoveryEmails.AsNoTracking().ToListAsync(), x => x.Status == "SENT");
            _clock.Advance(TimeSpan.FromDays(8));
            await new RecoveryEmailDispatcher(db, Secrets, sender, _clock, NullLogger<RecoveryEmailDispatcher>.Instance).PurgeAsync(7, default);
            Assert.Empty(await db.RecoveryChallenges.AsNoTracking().ToListAsync());
            Assert.Empty(await db.RecoveryEmails.AsNoTracking().ToListAsync());
        }
    }

    [PostgresFact]
    public async Task Reset_racing_refresh_revokes_all_old_sessions_and_stale_password_proof_cannot_issue_a_new_session()
    {
        var user = await SeedAsync(); IssuedTokenPair tokens;
        await using (var db = Context()) tokens = await Sessions(db).IssueAsync(user, default);
        var grant = await GrantAsync(user);
        var rotate = Task.Run(async () => { await using var db = Context(); return await Sessions(db).RotateAsync(tokens.RefreshToken, default); });
        await using (var db = Context()) Assert.True((await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default)).IsSuccess);
        await rotate;
        await using var check = Context();
        Assert.False(await check.RefreshTokenSessions.AnyAsync(x => x.UserId == user.Id && x.RevokedAt == null));
        await Assert.ThrowsAsync<AuthenticationStateChangedException>(() => Sessions(check).IssueAsync(user, default));
    }

    [PostgresFact]
    public async Task Reset_failure_rolls_back_password_grant_and_session_revocation_together()
    {
        var user = await SeedAsync(); IssuedTokenPair tokens;
        await using (var db = Context()) tokens = await Sessions(db).IssueAsync(user, default);
        var grant = await GrantAsync(user);
        await using (var db = Context())
        {
            await db.Database.ExecuteSqlRawAsync("""
                CREATE FUNCTION identity.fail_recovery_test() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN IF NEW.action = 'PASSWORD_RECOVERY_COMPLETED' THEN RAISE EXCEPTION 'test rollback'; END IF; RETURN NEW; END $$;
                CREATE TRIGGER fail_recovery BEFORE INSERT ON identity.audit_logs FOR EACH ROW EXECUTE FUNCTION identity.fail_recovery_test();
                """);
            await Assert.ThrowsAsync<DbUpdateException>(() => Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default));
        }
        await using (var db = Context())
        {
            Assert.True(_hasher.Verify("OldPassword123", (await db.Users.SingleAsync(x => x.Id == user.Id)).PasswordHash));
            Assert.True(await new AccessSessionValidator(db).IsActiveAsync(user.Id, (await db.RefreshTokenSessions.SingleAsync(x => x.TokenHash == new JwtTokenService(Jwt).HashRefreshToken(tokens.RefreshToken))).Id));
            await db.Database.ExecuteSqlRawAsync("DROP TRIGGER fail_recovery ON identity.audit_logs; DROP FUNCTION identity.fail_recovery_test();");
            Assert.True((await Recovery(db).ResetAsync(grant.ResetToken, "NewPassword456", default)).IsSuccess);
        }
    }

    [PostgresFact]
    public async Task Otp_login_verifies_legacy_email_and_plain_profile_update_cannot_change_it()
    {
        var user = await SeedAsync(false); await using var app = await ServerAsync();
        await using (var scope = app.Services.CreateAsyncScope()) await scope.ServiceProvider.GetRequiredService<IOtpStore>()
            .SaveAsync(user.Email, "123456", TimeSpan.FromMinutes(10), TimeSpan.FromSeconds(60));
        var client = app.GetTestClient(); var login = await client.PostAsJsonAsync("/api/v1/auth/login", new { email = user.Email, otp = "123456" });
        var auth = (await login.Content.ReadFromJsonAsync<LoginResponse>())!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var changed = await client.PutAsJsonAsync("/api/v1/profile", new { fullName = "Test user", email = "unproven@example.com" });
        Assert.Equal(HttpStatusCode.BadRequest, changed.StatusCode);
        await using var db = Context(); Assert.NotNull((await db.Users.SingleAsync(x => x.Id == user.Id)).EmailVerifiedAt);
    }

    [PostgresFact]
    public async Task Reset_disconnects_an_existing_realtime_connection()
    {
        var user = await SeedAsync();
        await using var app = await ServerAsync(); var client = app.GetTestClient();
        var login = await client.PostAsJsonAsync("/api/v1/auth/login/password", new { email = user.Email, password = "OldPassword123" });
        var auth = (await login.Content.ReadFromJsonAsync<LoginResponse>())!;
        var connector = app.GetTestServer().CreateWebSocketClient();
        connector.ConfigureRequest = message => message.Headers.Authorization = "Bearer " + auth.AccessToken;
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        using var socket = await connector.ConnectAsync(new Uri("ws://localhost/hubs/care-tracking"), timeout.Token);
        await socket.SendAsync(new ArraySegment<byte>(Encoding.UTF8.GetBytes("{\"protocol\":\"json\",\"version\":1}\u001e")), WebSocketMessageType.Text, true, timeout.Token);
        var buffer = new byte[1024];
        var handshake = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), timeout.Token);
        Assert.Contains("{}", Encoding.UTF8.GetString(buffer, 0, handshake.Count));
        // Wait for OnConnected's registration/validation, not a fixture-only socket.
        var grant = await GrantAsync(user);
        var reset = await client.PostAsJsonAsync("/api/v1/auth/password-recovery/reset", new
            { resetToken = grant.ResetToken, newPassword = "NewPassword456", confirmPassword = "NewPassword456" });
        Assert.Equal(HttpStatusCode.NoContent, reset.StatusCode);
        try
        {
            var terminated = false;
            for (var i = 0; i < 5 && !terminated; i++)
            {
                var closed = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), timeout.Token);
                terminated = closed.MessageType == WebSocketMessageType.Close ||
                    Encoding.UTF8.GetString(buffer, 0, closed.Count).Contains("\"type\":7", StringComparison.Ordinal);
            }
            Assert.True(terminated, "SignalR phải gửi thông báo đóng hoặc đóng transport của phiên bị thu hồi.");
        }
        catch (WebSocketException) { /* Server aborted the revoked connection. */ }
    }

    private async Task<WebApplication> ServerAsync()
    {
        var builder = WebApplication.CreateBuilder(); builder.WebHost.UseTestServer();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        { ["Jwt:Issuer"] = Jwt.Value.Issuer, ["Jwt:Audience"] = Jwt.Value.Audience, ["Jwt:SecretKey"] = Jwt.Value.SecretKey });
        builder.Services.AddDbContext<IdentityDbContext>(x => x.UseNpgsql(_database.ConnectionString));
        builder.Services.AddSingleton<IClock>(_clock); builder.Services.AddSingleton(_options);
        builder.Services.AddScoped<RecoverySecrets>(); builder.Services.AddScoped<IPasswordRecoveryService, PasswordRecoveryService>();
        builder.Services.AddScoped<IPasswordHasher, BcryptPasswordHasher>(); builder.Services.AddScoped<IIdentityStore, IdentityStore>();
        builder.Services.AddScoped<IRefreshTokenSessionService, RefreshTokenSessionService>();
        builder.Services.AddScoped<IAccessSessionValidator, AccessSessionValidator>();
        builder.Services.AddScoped<IOtpStore, OtpStore>(); builder.Services.AddScoped<IAuthenticationAttemptLimiter, AuthenticationAttemptLimiter>();
        builder.Services.AddHttpContextAccessor(); builder.Services.AddScoped<ICurrentUser, Actor>();
        builder.Services.AddDistributedMemoryCache(); builder.Services.AddJwtAuthentication(builder.Configuration);
        builder.Services.AddSignalR(); builder.Services.AddSingleton<RealtimeSessionRegistry>();
        builder.Services.AddMediatR(x => x.RegisterServicesFromAssemblyContaining<IdentityModule>());
        builder.Services.AddControllers().AddApplicationPart(typeof(PasswordRecoveryController).Assembly);
        var app = builder.Build(); app.UseAuthentication(); app.UseAuthorization(); app.MapControllers();
        app.MapHub<CareTrackingHub>("/hubs/care-tracking", options => options.CloseOnAuthenticationExpiration = true);
        await app.StartAsync(); return app;
    }
    private sealed class Actor(IHttpContextAccessor accessor) : ICurrentUser
    {
        public Guid? UserId => Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;
        public IReadOnlyCollection<string> Roles => accessor.HttpContext?.User.FindAll(ClaimTypes.Role).Select(x => x.Value).ToArray() ?? [];
        public bool IsInRole(string role) => Roles.Contains(role);
    }
    private sealed class TestClock : IClock
    { public DateTimeOffset UtcNow { get; private set; } = DateTimeOffset.UtcNow; public void Advance(TimeSpan delta) => UtcNow += delta; }
    private sealed class TestSender : IEmailSender
    {
        public bool Fail; public List<string> Subjects { get; } = [];
        public Task SendAsync(string to, string subject, string htmlBody, CancellationToken ct = default)
        { if (Fail) throw new IOException("SMTP unavailable"); Subjects.Add(subject); return Task.CompletedTask; }
    }
}
