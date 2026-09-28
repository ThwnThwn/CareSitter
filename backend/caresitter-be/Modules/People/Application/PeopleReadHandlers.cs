using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.People.Application;

internal sealed class ListBeneficiariesQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListBeneficiariesQuery, Result<IReadOnlyList<BeneficiaryResponse>>>
{
    public async Task<Result<IReadOnlyList<BeneficiaryResponse>>> Handle(
        ListBeneficiariesQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<BeneficiaryResponse>>(
            await store.ListBeneficiariesAsync(userId, ct));
    }
}

internal sealed class GetBeneficiaryQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetBeneficiaryQuery, Result<BeneficiaryResponse>>
{
    public async Task<Result<BeneficiaryResponse>> Handle(GetBeneficiaryQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var beneficiary = await store.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        return beneficiary is null ? PeopleErrors.NotFound() : beneficiary;
    }
}

internal sealed class ListFamilyContactsQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListFamilyContactsQuery, Result<IReadOnlyList<FamilyContactResponse>>>
{
    public async Task<Result<IReadOnlyList<FamilyContactResponse>>> Handle(
        ListFamilyContactsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        return Result.Success<IReadOnlyList<FamilyContactResponse>>(
            await store.ListFamilyContactsAsync(userId, ct));
    }
}

internal sealed class GetMyCaregiverProfileQueryHandler(
    IPeopleReadStore store,
    IUserProfileReader userProfiles,
    ICurrentUser currentUser) : IRequestHandler<GetMyCaregiverProfileQuery, Result<CaregiverProfileResponse>>
{
    public async Task<Result<CaregiverProfileResponse>> Handle(
        GetMyCaregiverProfileQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var avatarUrl = await userProfiles.GetAvatarUrlAsync(userId, ct);
        var profile = await store.GetCaregiverProfileAsync(userId, avatarUrl, ct);
        return profile is null ? PeopleErrors.CaregiverProfileNotFound() : profile;
    }
}

internal sealed class ListCaregiverKycQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<ListCaregiverKycQuery, Result<PeoplePage<CaregiverKycResponse>>>
{
    public async Task<Result<PeoplePage<CaregiverKycResponse>>> Handle(
        ListCaregiverKycQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();
        var page = Math.Max(request.Page, 1);
        var pageSize = Math.Clamp(request.PageSize, 1, 50);
        return await store.ListCaregiverKycAsync(request.Status, page, pageSize, ct);
    }
}

internal sealed class GetCaregiverKycQueryHandler(
    IPeopleReadStore store,
    ICurrentUser currentUser) : IRequestHandler<GetCaregiverKycQuery, Result<CaregiverKycResponse>>
{
    public async Task<Result<CaregiverKycResponse>> Handle(GetCaregiverKycQuery request, CancellationToken ct)
    {
        if (!currentUser.IsInRole("ADMIN")) return PeopleErrors.Forbidden();
        var profile = await store.GetCaregiverKycAsync(request.CaregiverId, ct);
        return profile is null ? PeopleErrors.CaregiverProfileNotFound() : profile;
    }
}

internal sealed class SearchCaregiversQueryHandler(
    IPeopleReadStore store) : IRequestHandler<SearchCaregiversQuery, PeoplePage<CaregiverResponse>>
{
    public Task<PeoplePage<CaregiverResponse>> Handle(SearchCaregiversQuery request, CancellationToken ct) =>
        store.SearchCaregiversAsync(new CaregiverSearchCriteria(
            request.Latitude, request.Longitude, request.City, request.District,
            request.Skill, request.MinimumRating, request.AvailabilityStatus,
            request.Start, request.End, Math.Max(request.Page, 1),
            Math.Clamp(request.PageSize, 1, 50)), ct);
}

internal sealed class GetApprovedCaregiverQueryHandler(
    IPeopleReadStore store) : IRequestHandler<GetApprovedCaregiverQuery, CaregiverResponse?>
{
    public Task<CaregiverResponse?> Handle(GetApprovedCaregiverQuery request, CancellationToken ct) =>
        store.GetApprovedCaregiverAsync(request.CaregiverId, ct);
}
