using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Catalog;
using CareSitter.Modules.Catalog.Infrastructure;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.ApproveCaregiverKyc;
using CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class KycMediaPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase database = null!;
    public async Task InitializeAsync() => database = await PostgresRaceTestDatabase.CreateAsync();
    public async Task DisposeAsync() { if (database is not null) await database.DisposeAsync(); }

    private ServiceProvider Services(KycMediaSecurityTests.Actor actor)
    {
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:CareSitter"] = database.ConnectionString }).Build();
        var services = new ServiceCollection();
        new CatalogModule().RegisterServices(services, configuration);
        new PeopleModule().RegisterServices(services, configuration);
        services.UseFixtureProvider<CatalogDbContext>();
        services.UseFixtureProvider<PeopleDbContext>();
        services.AddSingleton<ICurrentUser>(actor);
        services.AddSingleton<IEncryptionService, Encryption>();
        services.AddSingleton<IAuditLogger, KycMediaSecurityTests.Audit>();
        services.AddSingleton<IUserProfileReader, Avatars>();
        services.AddLogging();
        return services.BuildServiceProvider();
    }

    private async Task<CaregiverProfile> SeedAsync(IServiceProvider scope, Guid user)
    {
        await using var connection = await database.OpenConnectionAsync();
        await using var insert = new NpgsqlCommand("INSERT INTO identity.users(id,email,roles) VALUES (@id,@email,ARRAY['CAREGIVER']::varchar[])", connection);
        insert.Parameters.AddWithValue("id", user); insert.Parameters.AddWithValue("email", $"{user:N}@kyc.test");
        await insert.ExecuteNonQueryAsync();
        var db = scope.GetRequiredService<PeopleDbContext>();
        var profile = CaregiverProfile.Create(user).Value;
        db.CaregiverProfiles.Add(profile); await db.SaveChangesAsync();
        return profile;
    }

    private static KycMediaAsset Asset(Guid owner, string type)
    {
        var id = Guid.NewGuid();
        return new KycMediaAsset(id, owner, "unit-test-cloud", $"CareSitter/Kyc/{owner:D}/{id:N}", "png", type, 12);
    }

    [PostgresFact]
    public async Task Secure_submission_persists_ids_not_urls_and_admin_can_read_only_submitted_documents()
    {
        var actor = new KycMediaSecurityTests.Actor { Id = Guid.NewGuid() };
        using var services = Services(actor); using var scope = services.CreateScope(); var sp = scope.ServiceProvider;
        var profile = await SeedAsync(sp, actor.Id);
        var front = Asset(actor.Id, "CCCD_FRONT"); var back = Asset(actor.Id, "CCCD_BACK"); var orphan = Asset(actor.Id, "OTHER");
        var media = sp.GetRequiredService<IKycMediaStore>();
        foreach (var asset in new[] { front, back, orphan }) await media.AddAsync(asset, default);
        var sender = sp.GetRequiredService<ISender>();
        var submitted = await sender.Send(new SubmitCaregiverKycCommand("123456789012", front.Id, back.Id, []));
        Assert.True(submitted.IsSuccess, submitted.Error.Message);
        var access = sp.GetRequiredService<IKycDocumentAccess>();
        Assert.True(await access.IsSubmittedAsync(front.Id, actor.Id, default));
        Assert.False(await access.IsSubmittedAsync(orphan.Id, actor.Id, default));
        Assert.False(await access.IsSubmittedAsync(front.Id, Guid.NewGuid(), default));
        using var reloadedScope = services.CreateScope();
        var response = await reloadedScope.ServiceProvider.GetRequiredService<ISender>().Send(new GetMyCaregiverProfileQuery());
        Assert.True(response.IsSuccess); Assert.Equal(front.Id, response.Value.CccdFrontMediaId);
        Assert.Null(response.Value.CccdFrontUrl); Assert.Empty(response.Value.CertificateUrls);
        var catalog = reloadedScope.ServiceProvider.GetRequiredService<CatalogDbContext>();
        var saved = await catalog.MediaAssets.SingleAsync(x => x.Id == front.Id);
        Assert.Null(saved.Url); Assert.True(saved.IsSensitive); Assert.Equal("authenticated", saved.DeliveryType);
        actor.Role = "ADMIN";
        var approved = await sender.Send(new ApproveCaregiverKycCommand(profile.Id));
        Assert.True(approved.IsSuccess, approved.Error.Message);
    }

    [PostgresFact]
    public async Task Legacy_urls_are_hidden_in_owner_and_admin_dtos_and_cannot_be_approved()
    {
        var actor = new KycMediaSecurityTests.Actor { Id = Guid.NewGuid() };
        using var services = Services(actor); using var scope = services.CreateScope(); var sp = scope.ServiceProvider;
        var profile = await SeedAsync(sp, actor.Id);
        profile.SubmitKyc("encrypted", "hash", "https://cdn.invalid/front.png", "https://cdn.invalid/back.png", "[\"https://cdn.invalid/cert.png\"]");
        await sp.GetRequiredService<PeopleDbContext>().SaveChangesAsync();
        var sender = sp.GetRequiredService<ISender>();
        var mine = (await sender.Send(new GetMyCaregiverProfileQuery())).Value;
        Assert.True(mine.RequiresSecureResubmission); Assert.Null(mine.CccdFrontUrl); Assert.Null(mine.CccdBackUrl);
        Assert.Empty(mine.CertificateUrls); Assert.DoesNotContain("cdn.invalid", JsonSerializer.Serialize(mine));
        actor.Role = "ADMIN";
        var detail = (await sender.Send(new GetCaregiverKycQuery(profile.Id))).Value;
        Assert.True(detail.RequiresSecureResubmission); Assert.DoesNotContain("cdn.invalid", JsonSerializer.Serialize(detail));
        var decision = await sender.Send(new ApproveCaregiverKycCommand(profile.Id));
        Assert.True(decision.IsFailure); Assert.Equal("PENDING", profile.KycStatus);
        // Preserve legacy source for a separately authorized revoke/migration, not silent data deletion.
        Assert.Equal("https://cdn.invalid/front.png", profile.CccdFrontUrl);
    }

    [PostgresFact]
    public async Task Submit_command_rejects_another_accounts_document_before_changing_profile()
    {
        var actor = new KycMediaSecurityTests.Actor { Id = Guid.NewGuid() };
        using var services = Services(actor); using var scope = services.CreateScope(); var sp = scope.ServiceProvider;
        var mine = await SeedAsync(sp, actor.Id); var other = await SeedAsync(sp, Guid.NewGuid());
        var front = Asset(other.UserId, "CCCD_FRONT"); var back = Asset(actor.Id, "CCCD_BACK");
        var media = sp.GetRequiredService<IKycMediaStore>();
        await media.AddAsync(front, default); await media.AddAsync(back, default);
        var result = await sp.GetRequiredService<ISender>().Send(new SubmitCaregiverKycCommand("123456789012", front.Id, back.Id, []));
        Assert.True(result.IsFailure); Assert.Equal("DRAFT", mine.KycStatus); Assert.Null(mine.CccdNumberEncrypted);
    }

    private sealed class Encryption : IEncryptionService
    { public string Encrypt(string input) => "encrypted:" + input; public string Decrypt(string input) => throw new NotSupportedException(); public string Hmac(string input) => "hash:" + input; }
    private sealed class Avatars : IUserProfileReader
    { public Task<string?> GetAvatarUrlAsync(Guid user, CancellationToken ct) => Task.FromResult<string?>(null); }
}
