using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.SelfBeneficiary;
using CareSitter.Modules.People.Controllers;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class SelfBeneficiaryTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;
    private Guid _owner;
    private Guid _address;
    private Guid _relative;
    private string _role = "self_test_" + Guid.NewGuid().ToString("N");
    private readonly string _rolePassword = Guid.NewGuid().ToString("N");
    private string _connection = "";
    private NpgsqlDataSource _dataSource = null!;

    public async Task InitializeAsync()
    {
        _database = await PostgresRaceTestDatabase.CreateAsync();
        await using var connection = await _database.OpenConnectionAsync();
        await using (var command = new NpgsqlCommand("""
            SELECT b.customer_id, b.id, a.id FROM people.beneficiaries b
            JOIN catalog.addresses a ON a.owner_user_id = b.customer_id
            ORDER BY b.id, a.id LIMIT 1
            """, connection))
        await using (var reader = await command.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync());
            _owner = reader.GetGuid(0); _relative = reader.GetGuid(1); _address = reader.GetGuid(2);
        }
        // Role thật không owner/BYPASSRLS: mọi handler đều phải giữ owner và scope.
        // Mật khẩu riêng cho role test hỗ trợ SCRAM mà không nới quyền RLS.
        await using (var command = new NpgsqlCommand($"""
            CREATE ROLE "{_role}" LOGIN PASSWORD '{_rolePassword}';
            GRANT USAGE ON SCHEMA people, booking, identity TO "{_role}";
            GRANT SELECT, INSERT, UPDATE, DELETE ON people.beneficiaries TO "{_role}";
            GRANT SELECT ON booking.bookings, people.caregiver_profiles, identity.users TO "{_role}";
            """, connection)) await command.ExecuteNonQueryAsync();
        _connection = new NpgsqlConnectionStringBuilder(_database.ConnectionString)
        { Username = _role, Password = _rolePassword }.ConnectionString;
        var builder = new NpgsqlDataSourceBuilder(_connection);
        builder.UseNetTopologySuite();
        _dataSource = builder.Build();
    }

    public async Task DisposeAsync()
    {
        if (_database is null) return;
        if (_dataSource is not null) await _dataSource.DisposeAsync();
        using (var scoped = new NpgsqlConnection(_connection)) NpgsqlConnection.ClearPool(scoped);
        // Fixture xóa đúng DB test đã tạo trước khi xóa role chỉ dùng cho DB này.
        await _database.DisposeAsync();
        var admin = new NpgsqlConnectionStringBuilder(_database.ConnectionString) { Database = "postgres" };
        await using var connection = new NpgsqlConnection(admin.ConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"DROP ROLE IF EXISTS \"{_role}\"", connection);
        await command.ExecuteNonQueryAsync();
    }

    private ServiceProvider Services(Guid? owner, string role = "CUSTOMER", bool verified = true)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton(_dataSource);
        new PeopleModule().RegisterServices(services, new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["ConnectionStrings:CareSitter"] = _connection }).Build());
        services.UseFixtureProvider<PeopleDbContext>();
        services.AddSingleton<ICurrentUser>(new Actor(owner, role));
        services.AddSingleton<ICatalogLookupService>(new Catalog(_owner, _address, verified));
        return services.BuildServiceProvider();
    }

    private SelfBeneficiaryRequest Draft(string name = "Tôi") => new(name, new DateOnly(1990, 12, 23),
        "FEMALE", "0901234567", null, _address, "Nhẹ", "Ghi chú", null,
        JsonSerializer.SerializeToElement(new[] { new { name = "A", phone = "0901234567" }, new { name = "B", phone = "0912345678" } }));

    private async Task<IActionResult> CreateAsync(SelfBeneficiaryRequest? request = null)
    {
        await using var services = Services(_owner);
        await using var scope = services.CreateAsyncScope();
        return await new SelfBeneficiaryController(scope.ServiceProvider.GetRequiredService<IMediator>())
            .Create(request ?? Draft(), default);
    }

    private async Task<IActionResult> LinkAsync(Guid id, Guid? owner = null)
    {
        await using var services = Services(owner ?? _owner);
        await using var scope = services.CreateAsyncScope();
        return await new SelfBeneficiaryController(scope.ServiceProvider.GetRequiredService<IMediator>())
            .Link(new(id), default);
    }

    private static BeneficiaryResponse Profile(IActionResult response) =>
        Assert.IsType<BeneficiaryResponse>(Assert.IsAssignableFrom<ObjectResult>(response).Value);

    [PostgresFact]
    public async Task Concurrent_posts_create_one_self_and_retry_preserves_saved_data()
    {
        var responses = await Task.WhenAll(Enumerable.Range(0, 12).Select(i => CreateAsync(Draft($"Draft {i}"))));
        Assert.Single(responses.OfType<CreatedResult>());
        Assert.Equal(11, responses.OfType<OkObjectResult>().Count());
        var profiles = responses.Select(Profile).ToArray();
        Assert.Single(profiles.Select(p => p.Id).Distinct());
        Assert.Single(profiles.Select(p => p.FullName).Distinct());
        Assert.All(profiles, p => { Assert.True(p.IsSelf); Assert.Null(p.HealthHistory); Assert.Null(p.Allergies); Assert.Null(p.Medications); });
        var retry = await CreateAsync(Draft("Không ghi đè") with { DefaultAddressId = null, EmergencyContacts = null });
        Assert.IsType<OkObjectResult>(retry);
        Assert.Equal(profiles[0].Id, Profile(retry).Id);
        Assert.Equal(profiles[0].FullName, Profile(retry).FullName);
    }

    [PostgresFact]
    public async Task Post_racing_link_returns_one_identity_without_merging_profiles()
    {
        var responses = await Task.WhenAll(CreateAsync(), LinkAsync(_relative));
        var success = responses.OfType<ObjectResult>().Where(r => r.StatusCode < 300).Select(Profile).ToArray();
        Assert.NotEmpty(success);
        Assert.Single(success.Select(p => p.Id).Distinct());
        if (responses[1] is ConflictObjectResult conflict)
            Assert.Equal("beneficiary.self_exists", Assert.IsType<ProblemDetails>(conflict.Value).Title);
    }

    [PostgresFact]
    public async Task Competing_links_preserve_health_and_repeated_link_is_safe()
    {
        var other = Guid.NewGuid();
        await SqlAsync("INSERT INTO people.beneficiaries(id, customer_id, full_name) VALUES (@id, @owner, 'Hồ sơ cũ')", other);
        await SqlAsync("UPDATE people.beneficiaries SET allergies = '[\"allergen\"]', medications = '[\"medicine\"]' WHERE id = @id", _relative);
        var responses = await Task.WhenAll(LinkAsync(_relative), LinkAsync(other));
        var winner = Profile(Assert.Single(responses.OfType<OkObjectResult>()));
        Assert.Single(responses.OfType<ConflictObjectResult>());
        Assert.Equal(winner.Id, Profile(await LinkAsync(winner.Id)).Id);
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("SELECT allergies->>0, medications->>0 FROM people.beneficiaries WHERE id = @id", connection);
        command.Parameters.AddWithValue("id", _relative);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal("allergen", reader.GetString(0)); Assert.Equal("medicine", reader.GetString(1));
    }

    [PostgresFact]
    public async Task Role_owner_deleted_and_validation_guards_are_enforced()
    {
        foreach (var (owner, role) in new (Guid?, string)[] { (null, "CUSTOMER"), (_owner, "CAREGIVER") })
        {
            await using var services = Services(owner, role);
            var mediator = services.GetRequiredService<IMediator>();
            var result = await mediator.Send(new GetSelfBeneficiaryQuery());
            Assert.True(result.IsFailure);
            Assert.Equal(owner is null ? "people.unauthenticated" : "beneficiary.customer_required", result.Error.Code);
        }
        Assert.IsType<NotFoundResult>(await LinkAsync(_relative, Guid.NewGuid()));
        await SqlAsync("UPDATE people.beneficiaries SET deleted_at=now() WHERE id=@id", _relative);
        Assert.IsType<NotFoundResult>(await LinkAsync(_relative));
        var duplicates = JsonSerializer.SerializeToElement(new[] { new { name = "A", phone = "0901234567" }, new { name = "B", phone = "+84 901234567" } });
        var invalid = Assert.IsType<BadRequestObjectResult>(await CreateAsync(Draft() with { EmergencyContacts = duplicates }));
        Assert.Equal("beneficiary.emergency_contacts", Assert.IsType<ProblemDetails>(invalid.Value).Title);
        Assert.IsType<BadRequestObjectResult>(await CreateAsync(Draft() with { DateOfBirth = new DateOnly(2999, 1, 1) }));
        Assert.IsType<BadRequestObjectResult>(await CreateAsync(Draft() with { DefaultAddressId = Guid.NewGuid() }));
        await using var unverified = Services(_owner, verified: false);
        Assert.IsType<BadRequestObjectResult>(await new SelfBeneficiaryController(unverified.GetRequiredService<IMediator>()).Create(Draft(), default));
    }

    [PostgresFact]
    public async Task Get_is_read_only_and_rls_prevents_cross_owner_queries()
    {
        await using var services = Services(_owner);
        var mediator = services.GetRequiredService<IMediator>();
        var empty = await mediator.Send(new GetSelfBeneficiaryQuery());
        Assert.Equal("beneficiary.self_not_found", empty.Error.Code);
        var saved = Profile(await CreateAsync());
        var found = await mediator.Send(new GetSelfBeneficiaryQuery());
        Assert.Equal(saved.Id, found.Value.Id);
        await using var scoped = new NpgsqlConnection(_connection);
        await scoped.OpenAsync();
        await using var tx = await scoped.BeginTransactionAsync();
        await using var command = new NpgsqlCommand("SELECT set_config('app.current_user_id', @owner, true); SELECT count(*) FROM people.beneficiaries", scoped, tx);
        command.Parameters.AddWithValue("owner", Guid.NewGuid().ToString());
        await using var reader = await command.ExecuteReaderAsync();
        await reader.NextResultAsync(); Assert.True(await reader.ReadAsync()); Assert.Equal(0, reader.GetInt64(0));
    }

    [PostgresFact]
    public async Task Self_cannot_be_deleted_or_reclassified_and_archived_self_is_not_recreated()
    {
        var profile = Profile(await CreateAsync());
        await using var services = Services(_owner);
        var controller = new BeneficiariesController(services.GetRequiredService<IMediator>());
        var deleted = Assert.IsType<ConflictObjectResult>(await controller.Delete(profile.Id, default));
        Assert.Equal("beneficiary.self_managed", Assert.IsType<ProblemDetails>(deleted.Value).Title);
        // Separate scope prevents a tracked record from hiding database changes.
        await using (var updateServices = Services(_owner))
        {
            var request = JsonSerializer.Deserialize<BeneficiaryUpdateRequest>(JsonSerializer.Serialize(new {
                fullName = "Tên mới", defaultAddressId = _address, relationshipToCustomer = "Mẹ", isSelf = false
            }), new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
            var result = await new BeneficiariesController(updateServices.GetRequiredService<IMediator>()).Update(profile.Id, request, default);
            Assert.Equal("beneficiary.self_relationship", Assert.IsType<ProblemDetails>(Assert.IsType<BadRequestObjectResult>(result).Value).Title);
        }
        await SqlAsync("UPDATE people.beneficiaries SET deleted_at=now() WHERE id=@id", profile.Id);
        var archived = Assert.IsType<ConflictObjectResult>(await CreateAsync());
        Assert.Equal("beneficiary.self_archived", Assert.IsType<ProblemDetails>(archived.Value).Title);
    }

    [PostgresFact]
    public async Task Unique_index_guards_raw_writes_and_old_profiles_default_to_false()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using (var command = new NpgsqlCommand("SELECT count(*) FROM people.beneficiaries WHERE is_self", connection))
            Assert.Equal(0L, await command.ExecuteScalarAsync());
        await CreateAsync();
        var error = await Assert.ThrowsAsync<PostgresException>(() => SqlAsync(
            "INSERT INTO people.beneficiaries(id,customer_id,full_name,is_self) VALUES(@id,@owner,'Trùng',true)", Guid.NewGuid()));
        Assert.Equal("ux_beneficiaries_active_self_customer", error.ConstraintName);
        await using var migration = new NpgsqlCommand(await File.ReadAllTextAsync(MigrationPath()), connection);
        await migration.ExecuteNonQueryAsync();
    }

    [PostgresFact]
    public async Task Upgrade_existing_rows_preserves_health_and_assigns_false()
    {
        await SqlAsync("UPDATE people.beneficiaries SET allergies='[\"preserved\"]' WHERE id=@id", _relative);
        await using var connection = await _database.OpenConnectionAsync();
        // Chỉ DB ngẫu nhiên của fixture: đưa bảng về cấu trúc trước migration 37.
        await using (var before = new NpgsqlCommand("ALTER TABLE people.beneficiaries DROP COLUMN is_self", connection))
            await before.ExecuteNonQueryAsync();
        await using (var upgrade = new NpgsqlCommand(await File.ReadAllTextAsync(MigrationPath()), connection))
            await upgrade.ExecuteNonQueryAsync();
        await using var check = new NpgsqlCommand("SELECT is_self, allergies->>0 FROM people.beneficiaries WHERE id=@id", connection);
        check.Parameters.AddWithValue("id", _relative);
        await using var reader = await check.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync()); Assert.False(reader.GetBoolean(0)); Assert.Equal("preserved", reader.GetString(1));
    }

    [PostgresFact]
    public async Task Delete_racing_link_cannot_delete_an_active_self()
    {
        async Task<IActionResult> DeleteAsync()
        {
            await using var services = Services(_owner);
            return await new BeneficiariesController(services.GetRequiredService<IMediator>()).Delete(_relative, default);
        }
        var results = await Task.WhenAll(LinkAsync(_relative), DeleteAsync());
        if (results[0] is OkObjectResult) Assert.IsType<ConflictObjectResult>(results[1]);
        else { Assert.IsType<NotFoundResult>(results[0]); Assert.IsType<NoContentResult>(results[1]); }
    }

    private static string MigrationPath()
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
        {
            var path = Path.Combine(
                directory.FullName,
                "init-db",
                "modules",
                "people",
                "37-beneficiary-self-profile.sql");
            if (File.Exists(path)) return path;
        }
        throw new FileNotFoundException("Không tìm thấy migration 37.");
    }

    private async Task SqlAsync(string sql, Guid id)
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("id", id); command.Parameters.AddWithValue("owner", _owner);
        await command.ExecuteNonQueryAsync();
    }

    private sealed class Actor(Guid? id, string role) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => [role];
        public bool IsInRole(string value) => value == role;
    }

    private sealed class Catalog(Guid owner, Guid address, bool verified) : ICatalogLookupService
    {
        public Task<bool> AddressBelongsToAsync(Guid id, Guid user, CancellationToken ct = default) => Task.FromResult(id == address && user == owner);
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid id, Guid user, CancellationToken ct = default) => Task.FromResult(id == address && user == owner && verified);
        public Task<bool> ServiceIsActiveAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
