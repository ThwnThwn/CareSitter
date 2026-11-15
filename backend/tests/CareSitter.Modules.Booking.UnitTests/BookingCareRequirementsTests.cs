using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingCareRequirementsTests
{
    [Fact]
    public async Task Client_cannot_remove_service_or_owned_profile_needs_and_union_is_normalized()
    {
        var result = await BookingCareRequirements.ResolveAsync(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), [], new People(), new Catalog(), default);
        Assert.True(result.IsSuccess);
        Assert.Equal(new[] { "chuan bi bua an", "ho tro di chuyen" }, result.Value);
        var repeated = await BookingCareRequirements.ResolveAsync(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), [" CHUAN  BI BUA AN "], new People(), new Catalog(), default);
        Assert.Equal(result.Value, repeated.Value);
    }
    [Fact]
    public async Task Invalid_declared_needs_are_rejected_instead_of_silently_ignored()
    {
        var result = await BookingCareRequirements.ResolveAsync(Guid.NewGuid(), null, Guid.NewGuid(),
            [""], new People(), new Catalog(), default);
        Assert.True(result.IsFailure);
    }
    private sealed class Catalog : ICatalogLookupService
    {
        public Task<IReadOnlyList<string>> GetRequiredCaregiverSkillsAsync(Guid id, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<string>>(["chuan bi bua an"]);
        public Task<bool> AddressBelongsToAsync(Guid a, Guid b, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid a, Guid b, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> ServiceIsActiveAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<(double Lat,double Lng)?> GetAddressLocationAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
    }
    private sealed class People : IPeopleLookupService
    {
        public Task<IReadOnlyList<string>> GetRequiredCaregiverSkillsAsync(Guid id, Guid owner, CancellationToken ct = default) => Task.FromResult<IReadOnlyList<string>>(["ho tro di chuyen"]);
        public Task<bool> BeneficiaryBelongsToAsync(Guid a, Guid b, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> CaregiverIsAvailableAsync(Guid a, DateTimeOffset b, DateTimeOffset c, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<bool> IsCaregiverForBookingAsync(Guid a, Guid b, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid a, CancellationToken ct = default) => throw new NotSupportedException();
    }
}
