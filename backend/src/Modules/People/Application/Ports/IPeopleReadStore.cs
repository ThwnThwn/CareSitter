using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

public interface IPeopleReadStore
{
    Task<IReadOnlyList<BeneficiaryResponse>> ListBeneficiariesAsync(
        Guid customerId, CancellationToken ct = default);

    Task<BeneficiaryResponse?> GetBeneficiaryAsync(
        Guid beneficiaryId, Guid customerId, CancellationToken ct = default);

    Task<IReadOnlyList<FamilyContactResponse>> ListFamilyContactsAsync(
        Guid customerId, CancellationToken ct = default);

    Task<CaregiverProfileResponse?> GetCaregiverProfileAsync(
        Guid userId, string? avatarUrl, CancellationToken ct = default);

    Task<PeoplePage<CaregiverKycResponse>> ListCaregiverKycAsync(
        string? status, int page, int pageSize, CancellationToken ct = default);

    Task<CaregiverKycResponse?> GetCaregiverKycAsync(
        Guid caregiverId, CancellationToken ct = default);

    Task<PeoplePage<CaregiverResponse>> SearchCaregiversAsync(
        CaregiverSearchCriteria criteria, CancellationToken ct = default);

    Task<CaregiverResponse?> GetApprovedCaregiverAsync(
        Guid caregiverId, CancellationToken ct = default);
}
