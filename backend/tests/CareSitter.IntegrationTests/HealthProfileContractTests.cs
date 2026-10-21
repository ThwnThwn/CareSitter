using System.Reflection;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People;
using CareSitter.Modules.People.Application.Commands.HealthProfile;
using CareSitter.Modules.People.Domain;
using MediatR;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.IntegrationTests;

public sealed class HealthProfileContractTests
{
    [Theory]
    [InlineData("{\"medications\":\"unknown\"}")]
    [InlineData("{\"medications\":[{\"name\":\"A\",\"is_active\":\"false\"}]}")]
    [InlineData("{\"medications\":[{\"name\":\"A\",\"start_date\":\"2026-10-10\",\"end_date\":\"2026-01-01\"}]}")]
    [InlineData("{\"medications\":[{\"name\":\"\"}]}")]
    [InlineData("{\"chronicConditions\":[{\"label\":\"A\",\"assertion\":\"diagnosed\"}]}")]
    [InlineData("{\"chronicConditions\":[{\"label\":\"A\",\"subject\":\"other\"}]}")]
    [InlineData("{\"nutritionProfile\":{\"swallowingStatus\":\"soft\"}}")]
    [InlineData("{\"nutritionProfile\":{\"dietaryPattern\":\"pescatarian\"}}")]
    [InlineData("{\"nutritionProfile\":{\"nutritionGoal\":\"bulk\"}}")]
    [InlineData("{\"nutritionProfile\":{\"feedingRoute\":true}}")]
    [InlineData("{\"nutritionProfile\":{\"schemaVersion\":2}}")]
    [InlineData("{\"nutritionProfile\":{},\"healthHistory\":null}")]
    [InlineData("{\"nutritionProfile\":{\"medicationsStatus\":\"reported_none\",\"medicationsStatus\":\"reported_present\"}}")]
    [InlineData("{\"allergies\":[{\"name\":\"A\"}]}")]
    public async Task Invalid_structured_changes_do_not_write(string json)
    {
        await using var fixture = new Fixture();
        var result = await fixture.PatchAsync(json);
        Assert.Equal("nutrition.health_payload", result.Error.Code);
        Assert.Equal(0, fixture.Repository.Writes);
    }

    [Fact]
    public async Task Structured_patch_merges_without_replacing_history_restrictions_or_medications()
    {
        await using var fixture = new Fixture();
        fixture.Seed("""{"legacy":{"note":"keep"},"nutrition":{"schemaVersion":1,"feedingRoute":"tube","conditionsStatus":"reported_present"}}""",
            """[{"name":"A","dosage":"old dosage","is_active":true}]""");
        var result = await fixture.PatchAsync("""{"nutritionProfile":{"medicationsStatus":"reported_present","fluidRestriction":"present","dietaryPattern":"vegetarian","nutritionGoal":"gain"}}""");
        Assert.True(result.IsSuccess);
        var history = result.Value.HealthHistory!.Value;
        Assert.Equal("keep", history.GetProperty("legacy").GetProperty("note").GetString());
        Assert.Equal("tube", history.GetProperty("nutrition").GetProperty("feedingRoute").GetString());
        Assert.Equal("present", history.GetProperty("nutrition").GetProperty("fluidRestriction").GetString());
        Assert.Equal("vegetarian", history.GetProperty("nutrition").GetProperty("dietaryPattern").GetString());
        Assert.Equal("gain", history.GetProperty("nutrition").GetProperty("nutritionGoal").GetString());
        Assert.Equal("old dosage", result.Value.Medications!.Value[0].GetProperty("dosage").GetString());
        Assert.Null(result.Value.GeneralNote);
    }

    [Theory]
    [InlineData("[]", "nutrition.legacy_health")]
    [InlineData("{\"nutrition\":\"legacy\"}", "nutrition.legacy_health")]
    [InlineData("{\"nutrition\":{\"schemaVersion\":2}}", "nutrition.health_schema")]
    public async Task Incompatible_history_is_preserved_and_plain_note_can_still_be_saved(string history, string code)
    {
        await using var fixture = new Fixture(); fixture.Seed(history);
        var rejected = await fixture.PatchAsync("""{"nutritionProfile":{"feedingRoute":"oral"}}""");
        Assert.Equal(code, rejected.Error.Code); Assert.Equal(0, fixture.Repository.Writes);
        Assert.Equal(history, fixture.Entity.HealthHistory);
        var note = await fixture.PatchAsync("""{"generalNote":"new note"}""");
        Assert.True(note.IsSuccess); Assert.Equal(history, fixture.Entity.HealthHistory);
    }

    [Fact]
    public async Task Active_medication_cannot_be_relabelled_as_no_medication()
    {
        await using var fixture = new Fixture();
        fixture.Seed(null, """[{"name":"A","is_active":true}]""");
        var rejected = await fixture.PatchAsync("""{"nutritionProfile":{"medicationsStatus":"reported_none"}}""");
        Assert.Equal("nutrition.medication_conflict", rejected.Error.Code); Assert.Equal(0, fixture.Repository.Writes);
        var inactive = await fixture.PatchAsync("""{"nutritionProfile":{"medicationsStatus":"reported_none"},"medications":[{"name":"A","is_active":false}]}""");
        Assert.True(inactive.IsSuccess);
        Assert.False(inactive.Value.Medications!.Value[0].GetProperty("is_active").GetBoolean());
    }

    [Fact]
    public async Task Unknown_profile_fields_can_be_saved_as_draft_but_stale_and_foreign_writes_fail()
    {
        await using var fixture = new Fixture();
        var draft = await fixture.PatchAsync("""{"nutritionProfile":{"feedingRoute":"unknown","medicationsStatus":"unknown"}}""");
        Assert.True(draft.IsSuccess);
        var stale = await fixture.PatchAsync("{}", revision: 9);
        Assert.Equal("nutrition.profile_changed", stale.Error.Code);
        var foreign = await fixture.Mediator.Send(new UpdateHealthProfileCommand(Guid.NewGuid(), 1, JsonSerializer.SerializeToElement(new { generalNote = "hidden" })));
        Assert.Equal("nutrition.profile_not_found", foreign.Error.Code);
        Assert.Equal(1, fixture.Repository.Writes);
    }

    private sealed class Fixture : IAsyncDisposable
    {
        private readonly ServiceProvider _services;
        public Beneficiary Entity { get; } = Beneficiary.Create(Guid.NewGuid(), "Fixture").Value;
        public RepositoryProxy Repository { get; }
        public IMediator Mediator => _services.GetRequiredService<IMediator>();
        public Fixture()
        {
            var repository = DispatchProxy.Create<IPeopleRepository, RepositoryProxy>();
            Repository = (RepositoryProxy)(object)repository; Repository.Entity = Entity;
            var services = new ServiceCollection(); services.AddLogging();
            services.AddMediatR(c => c.RegisterServicesFromAssemblyContaining<PeopleModule>());
            services.AddSingleton(repository); services.AddSingleton<ICurrentUser>(new Actor(Entity.CustomerId));
            _services = services.BuildServiceProvider();
        }
        public void Seed(string? history, string? medications = null) =>
            Assert.True(Entity.UpdateHealth(1, null, null, history, null, null, medications, "unknown", Entity.CustomerId, DateTimeOffset.UtcNow).IsSuccess);
        public Task<CareSitter.SharedKernel.Results.Result<CareSitter.Contracts.Nutrition.BeneficiaryHealthSnapshot>> PatchAsync(string json, long revision = 1) =>
            Mediator.Send(new UpdateHealthProfileCommand(Entity.Id, revision, JsonSerializer.Deserialize<JsonElement>(json)));
        public ValueTask DisposeAsync() => _services.DisposeAsync();
    }

    public class RepositoryProxy : DispatchProxy
    {
        public Beneficiary Entity = null!; public int Writes;
        protected override object? Invoke(MethodInfo? method, object?[]? args) => method!.Name switch
        {
            nameof(IPeopleRepository.BeginUserScopeAsync) => Task.FromResult<IPeopleTransaction>(new Transaction()),
            nameof(IPeopleRepository.GetBeneficiaryAsync) => Task.FromResult((Guid)args![0]! == Entity.Id && (Guid)args[1]! == Entity.CustomerId ? Entity : null),
            nameof(IPeopleRepository.SaveChangesAsync) => SaveAsync(),
            _ => throw new InvalidOperationException(method.Name)
        };
        private Task SaveAsync() { Writes++; return Task.CompletedTask; }
    }
    private sealed class Transaction : IPeopleTransaction
    { public Task CommitAsync(CancellationToken ct = default) => Task.CompletedTask; public ValueTask DisposeAsync() => ValueTask.CompletedTask; }
    private sealed class Actor(Guid id) : ICurrentUser
    { public Guid? UserId => id; public IReadOnlyCollection<string> Roles => ["CUSTOMER"]; public bool IsInRole(string role) => role == "CUSTOMER"; }
}
