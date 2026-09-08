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
}

public interface ICatalogLookupService
{
    Task<bool> AddressBelongsToAsync(Guid addressId, Guid customerId, CancellationToken ct = default);
    Task<bool> ServiceIsActiveAsync(Guid serviceTypeId, CancellationToken ct = default);
    /// <summary>Tra ve lat/lng cua address. Null neu khong tim thay.</summary>
    Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid addressId, CancellationToken ct = default);
}
