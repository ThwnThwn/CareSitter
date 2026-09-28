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

public sealed record ListBeneficiariesQuery : IRequest<Result<IReadOnlyList<BeneficiaryResponse>>>;
public sealed record GetBeneficiaryQuery(Guid BeneficiaryId) : IRequest<Result<BeneficiaryResponse>>;
public sealed record ListFamilyContactsQuery : IRequest<Result<IReadOnlyList<FamilyContactResponse>>>;
public sealed record GetMyCaregiverProfileQuery : IRequest<Result<CaregiverProfileResponse>>;
public sealed record ListCaregiverKycQuery(
    string? Status, int Page, int PageSize) : IRequest<Result<PeoplePage<CaregiverKycResponse>>>;
public sealed record GetCaregiverKycQuery(Guid CaregiverId) : IRequest<Result<CaregiverKycResponse>>;
public sealed record SearchCaregiversQuery(
    double? Latitude,
    double? Longitude,
    string? City,
    string? District,
    string? Skill,
    decimal? MinimumRating,
    string? AvailabilityStatus,
    DateTimeOffset? Start,
    DateTimeOffset? End,
    int Page,
    int PageSize) : IRequest<PeoplePage<CaregiverResponse>>;
public sealed record GetApprovedCaregiverQuery(Guid CaregiverId) : IRequest<CaregiverResponse?>;

public sealed record CaregiverSearchCriteria(
    double? Latitude,
    double? Longitude,
    string? City,
    string? District,
    string? Skill,
    decimal? MinimumRating,
    string? AvailabilityStatus,
    DateTimeOffset? Start,
    DateTimeOffset? End,
    int Page,
    int PageSize);
