using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Controllers;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class HealthProfileTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _db=null!;private Guid _owner,_beneficiary;
    private NpgsqlDataSource _dataSource=null!;
    public async Task InitializeAsync()
    {
        _db=await PostgresRaceTestDatabase.CreateAsync();
        var dataSourceBuilder=new NpgsqlDataSourceBuilder(_db.ConnectionString);
        dataSourceBuilder.UseNetTopologySuite();
        _dataSource=dataSourceBuilder.Build();
        await using var c=await _db.OpenConnectionAsync();
        await using var q=new NpgsqlCommand("SELECT customer_id,id FROM people.beneficiaries WHERE deleted_at IS NULL LIMIT 1",c);
        await using var r=await q.ExecuteReaderAsync();Assert.True(await r.ReadAsync());_owner=r.GetGuid(0);_beneficiary=r.GetGuid(1);
    }
    public async Task DisposeAsync()
    {
        if(_dataSource is not null)await _dataSource.DisposeAsync();
        if(_db is not null)await _db.DisposeAsync();
    }
    private ServiceProvider Services(Guid? owner=null,string role="CUSTOMER")
    {
        var services=new ServiceCollection();services.AddLogging();
        services.AddSingleton(_dataSource);
        new PeopleModule().RegisterServices(services,new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>{{"ConnectionStrings:CareSitter",_db.ConnectionString}}).Build());
        services.AddSingleton<ICurrentUser>(new Actor(owner??_owner,role));return services.BuildServiceProvider();
    }
    private async Task<BeneficiaryHealthSnapshot> ReadAsync()
    {
        await using var s=Services();return (await s.GetRequiredService<IBeneficiaryHealthSnapshotReader>().ReadAsync(_owner,_beneficiary))!;
    }
    private async Task<IActionResult> PatchAsync(long revision,object changes)
    {
        await using var s=Services();return await new HealthProfileController(s.GetRequiredService<IMediator>()).Patch(_beneficiary,new(revision,JsonSerializer.SerializeToElement(changes)),default);
    }
    [PostgresFact]
    public async Task Sparse_patch_keeps_legacy_health_and_returns_trigger_revision()
    {
        await SqlAsync("UPDATE people.beneficiaries SET allergies='[\"Tôm\"]',medications='[{\"name\":\"thuốc\"}]' WHERE id=@id");
        var before=await ReadAsync();var result=Assert.IsType<OkObjectResult>(await PatchAsync(before.Revision,new{generalNote="Cập nhật ghi chú"}));
        var saved=Assert.IsType<BeneficiaryHealthSnapshot>(result.Value);
        Assert.Equal(before.Revision+1,saved.Revision);Assert.Equal(before.Allergies!.Value.GetRawText(),saved.Allergies!.Value.GetRawText());
        Assert.Equal(before.Medications!.Value.GetRawText(),saved.Medications!.Value.GetRawText());Assert.Equal("unknown",saved.AllergyStatus);
    }
    [PostgresFact]
    public async Task Allergy_confirmation_is_explicit_and_notes_do_not_reconfirm()
    {
        await SqlAsync("UPDATE people.beneficiaries SET allergies='[\"Tôm\"]' WHERE id=@id");
        var before=await ReadAsync();var conflict=Assert.IsType<BadRequestObjectResult>(await PatchAsync(before.Revision,new{foodAllergyStatus="reported_none"}));
        Assert.Equal("nutrition.allergy_conflict",Assert.IsType<ProblemDetails>(conflict.Value).Title);
        Assert.IsType<OkObjectResult>(await PatchAsync(before.Revision,new{allergies=Array.Empty<string>(),foodAllergyStatus="reported_none"}));
        var confirmed=await ReadAsync();Assert.NotNull(confirmed.AllergyConfirmedAt);
        await PatchAsync(confirmed.Revision,new{careInstructions="Ghi chú mới"});
        Assert.Equal(confirmed.AllergyConfirmedAt,(await ReadAsync()).AllergyConfirmedAt);
        await SqlAsync("UPDATE people.beneficiaries SET allergies='[\"Trứng\"]' WHERE id=@id");
        var legacyUpdate=await ReadAsync();Assert.Equal("unknown",legacyUpdate.AllergyStatus);Assert.Null(legacyUpdate.AllergyConfirmedAt);
    }
    [PostgresFact]
    public async Task Concurrent_patches_do_not_overwrite_same_revision()
    {
        var before=await ReadAsync();var results=await Task.WhenAll(PatchAsync(before.Revision,new{generalNote="A"}),PatchAsync(before.Revision,new{generalNote="B"}));
        Assert.Single(results.OfType<OkObjectResult>());Assert.Single(results.OfType<ConflictObjectResult>());
        Assert.Equal(before.Revision+1,(await ReadAsync()).Revision);
    }
    [PostgresFact]
    public async Task Snapshot_reads_exact_owner_and_excludes_deleted_profile()
    {
        await using var s=Services();var reader=s.GetRequiredService<IBeneficiaryHealthSnapshotReader>();
        Assert.Null(await reader.ReadAsync(Guid.NewGuid(),_beneficiary));
        Assert.Null(await reader.ReadAsync(_owner,Guid.NewGuid()));
        await SqlAsync("UPDATE people.beneficiaries SET deleted_at=now() WHERE id=@id");
        Assert.Null(await reader.ReadAsync(_owner,_beneficiary));
    }
    private async Task SqlAsync(string sql)
    {await using var c=await _db.OpenConnectionAsync();await using var q=new NpgsqlCommand(sql,c);q.Parameters.AddWithValue("id",_beneficiary);await q.ExecuteNonQueryAsync();}
    private sealed class Actor(Guid id,string role):ICurrentUser
    {public Guid? UserId=>id;public IReadOnlyCollection<string> Roles=>[role];public bool IsInRole(string value)=>value==role;}
}
