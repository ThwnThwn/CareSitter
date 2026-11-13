using CareSitter.Modules.Identity;
using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class GoogleAccountSignInPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    public async Task InitializeAsync() => database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (database is not null) await database.DisposeAsync(); }
    [PostgresFact]
    public async Task Firebase_and_legacy_google_share_account_roles_and_subject_without_duplicates()
    {
        var services = new ServiceCollection();
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?> {
            ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build();
        new IdentityModule().RegisterServices(services, config);
        services.UseFixtureProvider<IdentityDbContext>();
        services.AddLogging();
        var sessions = new Sessions();
        var identity = new GoogleIdentity("google-" + Guid.NewGuid().ToString("N"),
            $"{Guid.NewGuid():N}@auth.test", "Synthetic Demo");
        using var provider = services.BuildServiceProvider();
        Guid owner;
        using (var scope = provider.CreateScope())
        {
            var signIn = new GoogleAccountSignIn(scope.ServiceProvider.GetRequiredService<IIdentityStore>(), sessions);
            var firebase = new FirebaseGoogleLoginHandler(new Verifier(identity), signIn);
            var result = await firebase.Handle(new FirebaseGoogleLoginCommand("verified-firebase-token"), default);
            Assert.True(result.IsSuccess, result.Error.Message);
            Assert.True(result.Value.IsNewUser); owner = result.Value.UserId;
            Assert.Equal(new[] { "CUSTOMER" }, result.Value.Roles);
        }
        using (var scope = provider.CreateScope())
        {
            var signIn = new GoogleAccountSignIn(scope.ServiceProvider.GetRequiredService<IIdentityStore>(), sessions);
            var legacy = new GoogleLoginHandler(new Verifier(identity), signIn);
            var result = await legacy.Handle(new GoogleLoginCommand("verified-google-token", "CUSTOMER"), default);
            Assert.True(result.IsSuccess); Assert.False(result.Value.IsNewUser); Assert.Equal(owner, result.Value.UserId);
            var db = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            Assert.Equal(1, await db.Users.CountAsync(x => x.Email == identity.Email));
            Assert.Equal(identity.Subject, (await db.Users.SingleAsync(x => x.Id == owner)).GoogleId);
            var conflict = await signIn.SignInAsync(identity with { Subject = "another-subject" }, "CUSTOMER", default);
            Assert.Equal("auth.google_account_conflict", conflict.Error.Code);
            var admin = await legacy.Handle(new GoogleLoginCommand("token", "ADMIN"), default);
            Assert.True(admin.IsFailure); Assert.Equal(2, sessions.Issued);
        }
    }
    private sealed class Verifier(GoogleIdentity identity) : IGoogleIdentityVerifier, IFirebaseGoogleIdentityVerifier
    { public Task<Result<GoogleIdentity>> VerifyAsync(string token, CancellationToken ct = default) => Task.FromResult<Result<GoogleIdentity>>(identity); }
    private sealed class Sessions : IRefreshTokenSessionService
    {
        public int Issued;
        public Task<IssuedTokenPair> IssueAsync(User user, CancellationToken ct,
            string? deviceId = null, string? deviceInfo = null, string? ipAddress = null)
        { Issued++; return Task.FromResult(new IssuedTokenPair("synthetic-access", "synthetic-refresh")); }
        public Task<Result<IssuedTokenPair>> RotateAsync(string token, CancellationToken ct) => throw new NotSupportedException();
        public Task RevokeAsync(string token, CancellationToken ct) => Task.CompletedTask;
        public Task RevokeSessionAsync(Guid user, Guid session, CancellationToken ct) => Task.CompletedTask;
        public Task RevokeAllForUserAsync(Guid user, CancellationToken ct) => Task.CompletedTask;
    }
}
