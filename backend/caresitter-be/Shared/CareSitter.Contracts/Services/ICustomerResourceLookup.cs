using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

public interface IPeopleLookupService
{
    Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default);
    Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end,
        CancellationToken ct = default);
    Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default);
    Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default);
    Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default);
    Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default);
    Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default);
    Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default);
}

public interface ICatalogLookupService
{
    Task<bool> AddressBelongsToAsync(Guid addressId, Guid customerId, CancellationToken ct = default);
    Task<bool> AddressIsVerifiedForBookingAsync(Guid addressId, Guid customerId, CancellationToken ct = default);
    Task<bool> ServiceIsActiveAsync(Guid serviceTypeId, CancellationToken ct = default);
    Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid addressId, CancellationToken ct = default);
    Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid serviceTypeId, CancellationToken ct = default);
    /// <summary>Tra ve lat/lng cua address. Null neu khong tim thay.</summary>
    Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid addressId, CancellationToken ct = default);
}

public sealed record PeopleDisplaySummary(
    Guid Id,
    string DisplayName,
    int? Age = null,
    string? Gender = null,
    string? Relationship = null,
    string? Condition = null,
    string? Notes = null);
public sealed record AddressDisplaySummary(Guid Id, string FullAddress);
public sealed record ServiceDisplaySummary(Guid Id, string Name);
