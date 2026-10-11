using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;
using CareSitter.Modules.People.Controllers;
using CareSitter.Modules.People.Domain;
using FluentValidation;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Modules.People.UnitTests;

public sealed class BeneficiaryUpdateTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly Guid AddressId = Guid.NewGuid();

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Basic_edit_preserves_all_omitted_fields_in_both_json_casings(bool pascalCase)
    {
        var entity = Seed();
        var fields = new Dictionary<string, object?>
        {
            [pascalCase ? "FullName" : "fullName"] = "Tên đã sửa",
            [pascalCase ? "DefaultAddressId" : "defaultAddressId"] = AddressId,
            [pascalCase ? "GeneralNote" : "generalNote"] = "Ghi chú mới",
            // Client không được giả mạo metadata để xóa các trường vắng mặt.
            ["providedFields"] = new[] { "Allergies", "Medications" }
        };
        var (result, repository) = await UpdateAsync(entity, fields);
        var response = Assert.IsType<BeneficiaryResponse>(Assert.IsType<OkObjectResult>(result).Value);
        Assert.True(repository.Saved);
        Assert.True(repository.Committed);
        Assert.Equal("Tên đã sửa", response.FullName);
        Assert.Equal("Ghi chú mới", entity.GeneralNote);
        Assert.Equal(new DateOnly(1950, 12, 23), entity.DateOfBirth);
        Assert.Equal("FEMALE", entity.Gender);
        Assert.Equal("Mẹ", entity.RelationshipToCustomer);
        Assert.Equal("0901234567", entity.Phone);
        Assert.Equal("Cần hỗ trợ di chuyển", entity.MobilityNote);
        Assert.Equal("{\"note\":\"Tiền sử\"}", entity.HealthHistory);
        Assert.Equal("[\"test-allergen\"]", entity.Allergies);
        Assert.Equal("[\"test-condition\"]", entity.ChronicConditions);
        Assert.Equal("[\"test-medication\"]", entity.Medications);
        Assert.Equal("Lưu ý", entity.CareInstructions);
        Assert.Equal("Nặng", entity.CareLevel);
        Assert.Equal("https://example.test/avatar.jpg", entity.AvatarUrl);
        Assert.Equal("[{\"name\":\"Liên hệ\"}]", entity.EmergencyContacts);
    }

    [Fact]
    public async Task Explicit_null_clears_optional_fields_instead_of_preserving_them()
    {
        var entity = Seed();
        var fields = BasicFields();
        foreach (var name in new[] { "DateOfBirth", "Gender", "RelationshipToCustomer", "Phone",
                     "MobilityNote", "GeneralNote", "HealthHistory", "Allergies", "ChronicConditions",
                     "CareInstructions", "CareLevel", "AvatarUrl", "EmergencyContacts", "Medications" })
            fields[name] = null;
        var (result, repository) = await UpdateAsync(entity, fields);
        var response = Assert.IsType<BeneficiaryResponse>(Assert.IsType<OkObjectResult>(result).Value);
        Assert.True(repository.Committed);
        var json = JsonSerializer.SerializeToElement(response);
        foreach (var name in fields.Keys.Except(new[] { "FullName", "DefaultAddressId" }))
            Assert.Equal(JsonValueKind.Null, json.GetProperty(name).ValueKind);
    }

    [Fact]
    public async Task Supplied_health_data_replaces_only_the_specified_fields()
    {
        var entity = Seed();
        var fields = BasicFields();
        fields["allergies"] = Array.Empty<string>();
        fields["healthHistory"] = new { note = "Mới" };
        fields["gender"] = " male ";
        fields["dateOfBirth"] = "1960-02-29";
        var (result, _) = await UpdateAsync(entity, fields);
        Assert.IsType<OkObjectResult>(result);
        Assert.Equal("[]", entity.Allergies);
        Assert.Equal("Mới", JsonDocument.Parse(entity.HealthHistory!).RootElement.GetProperty("note").GetString());
        Assert.Equal("[\"test-medication\"]", entity.Medications);
        Assert.Equal("MALE", entity.Gender);
        Assert.Equal(new DateOnly(1960, 2, 29), entity.DateOfBirth);
    }

    [Theory]
    [InlineData("Gender", "invalid")]
    [InlineData("DateOfBirth", "2999-01-01")]
    [InlineData("DefaultAddressId", null)]
    public async Task Invalid_input_does_not_save_or_mutate_profile(string field, string? value)
    {
        var entity = Seed();
        var fields = BasicFields();
        fields[field] = value;
        var (result, repository) = await UpdateAsync(entity, fields);
        Assert.Equal(400, Assert.IsType<BadRequestObjectResult>(result).StatusCode);
        Assert.False(repository.Saved);
        Assert.Equal("Tên cũ", entity.FullName);
    }

    [Fact]
    public async Task Another_owner_cannot_update_the_profile()
    {
        var entity = Seed();
        var (result, repository) = await UpdateAsync(entity, BasicFields(), Guid.NewGuid());
        Assert.Equal(404, Assert.IsType<NotFoundResult>(result).StatusCode);
        Assert.False(repository.Saved);
        Assert.Equal("Tên cũ", entity.FullName);
    }

    private static Dictionary<string, object?> BasicFields() => new()
    {
        ["FullName"] = "Tên đã sửa", ["DefaultAddressId"] = AddressId
    };

    private static Beneficiary Seed()
    {
        var entity = Beneficiary.Create(Guid.NewGuid(), "Tên cũ").Value;
        Assert.True(entity.Update("Tên cũ", new DateOnly(1950, 12, 23), "FEMALE", "Mẹ",
            "0901234567", AddressId, "Cần hỗ trợ di chuyển", "Ghi chú",
            "{\"note\":\"Tiền sử\"}", "[\"test-allergen\"]", "[\"test-condition\"]", "Lưu ý",
            "Nặng", "https://example.test/avatar.jpg", "[{\"name\":\"Liên hệ\"}]",
            "[\"test-medication\"]").IsSuccess);
        return entity;
    }

    private static async Task<(IActionResult Result, Repository Repository)> UpdateAsync(
        Beneficiary entity, Dictionary<string, object?> fields, Guid? actorId = null)
    {
        var repository = new Repository(entity);
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMediatR(options => options.RegisterServicesFromAssemblyContaining<PeopleModule>());
        services.AddSingleton<IPeopleRepository>(repository);
        services.AddSingleton<ICurrentUser>(new CurrentUser(actorId ?? entity.CustomerId));
        services.AddSingleton<ICatalogLookupService>(new Catalog());
        services.AddSingleton<IValidator<UpdateBeneficiaryCommand>>(new UpdateBeneficiaryCommandValidator());
        await using var provider = services.BuildServiceProvider();
        var request = JsonSerializer.Deserialize<BeneficiaryUpdateRequest>(JsonSerializer.Serialize(fields), JsonOptions)!;
        var controller = new BeneficiariesController(provider.GetRequiredService<IMediator>());
        return (await controller.Update(entity.Id, request, CancellationToken.None), repository);
    }

    private sealed class CurrentUser(Guid userId) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => new[] { "CUSTOMER" };
        public bool IsInRole(string role) => Roles.Contains(role);
    }

    private sealed class Catalog : ICatalogLookupService
    {
        public Task<bool> AddressBelongsToAsync(Guid id, Guid user, CancellationToken ct = default) => Task.FromResult(id == AddressId);
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid id, Guid user, CancellationToken ct = default) => Task.FromResult(id == AddressId);
        public Task<bool> ServiceIsActiveAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
    }

    private sealed class Repository(Beneficiary entity) : IPeopleRepository, IPeopleTransaction
    {
        public bool Saved { get; private set; }
        public Task LockSelfBeneficiaryAsync(Guid customerId, CancellationToken ct = default) => Task.CompletedTask;
        public Task<Beneficiary?> GetSelfBeneficiaryAsync(Guid customerId, CancellationToken ct = default) =>
            Task.FromResult(entity.IsSelf && entity.CustomerId == customerId ? entity : null);
        public bool Committed { get; private set; }
        public Task<IPeopleTransaction> BeginUserScopeAsync(Guid id, CancellationToken ct = default) => Task.FromResult<IPeopleTransaction>(this);
        public Task<Beneficiary?> GetBeneficiaryAsync(Guid id, Guid customer, CancellationToken ct = default) =>
            Task.FromResult(id == entity.Id && customer == entity.CustomerId ? entity : null);
        public Task SaveChangesAsync(CancellationToken ct = default) { Saved = true; return Task.CompletedTask; }
        public Task CommitAsync(CancellationToken ct = default) { Committed = true; return Task.CompletedTask; }
        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
        public void AddBeneficiary(Beneficiary value) => throw new NotSupportedException();
        public Task<FamilyContact?> GetFamilyContactAsync(Guid id, Guid customer, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> FamilyPhoneExistsAsync(Guid customer, string phone, Guid? excluded, CancellationToken ct = default) => throw new NotSupportedException();
        public void AddFamilyContact(FamilyContact contact) => throw new NotSupportedException();
        public Task<CaregiverProfile?> GetCaregiverProfileByUserIdAsync(Guid user, bool tracking = true, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<CaregiverProfile?> GetCaregiverProfileByIdAsync(Guid id, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<CaregiverProfileCreationResult> AddCaregiverProfileIdempotentlyAsync(CaregiverProfile profile, Guid user, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
