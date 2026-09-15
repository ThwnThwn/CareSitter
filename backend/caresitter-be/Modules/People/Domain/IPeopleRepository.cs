namespace CareSitter.Modules.People.Domain;

public interface IPeopleTransaction : IAsyncDisposable
{
    Task CommitAsync(CancellationToken ct = default);
}

public sealed record CaregiverProfileCreationResult(CaregiverProfile Profile, bool Created);

public interface IPeopleRepository
{
    Task<IPeopleTransaction> BeginUserScopeAsync(Guid userId, CancellationToken ct = default);

    Task<Beneficiary?> GetBeneficiaryAsync(Guid id, Guid customerId, CancellationToken ct = default);
    void AddBeneficiary(Beneficiary beneficiary);

    Task<FamilyContact?> GetFamilyContactAsync(Guid id, Guid customerId, CancellationToken ct = default);
    Task<bool> FamilyPhoneExistsAsync(Guid customerId, string phoneNumber,
        Guid? excludedContactId, CancellationToken ct = default);
    void AddFamilyContact(FamilyContact contact);

    Task<CaregiverProfile?> GetCaregiverProfileByUserIdAsync(Guid userId,
        bool tracking = true, CancellationToken ct = default);
    Task<CaregiverProfile?> GetCaregiverProfileByIdAsync(Guid id, CancellationToken ct = default);
    Task<CaregiverProfileCreationResult> AddCaregiverProfileIdempotentlyAsync(
        CaregiverProfile profile, Guid userId, CancellationToken ct = default);
    Task<string?> GetAvatarUrlAsync(Guid userId, CancellationToken ct = default);

    Task SaveChangesAsync(CancellationToken ct = default);
}
