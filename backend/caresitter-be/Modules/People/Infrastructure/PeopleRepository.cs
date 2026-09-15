using CareSitter.Modules.People.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class PeopleRepository(PeopleDbContext db) : IPeopleRepository
{
    public async Task<IPeopleTransaction> BeginUserScopeAsync(
        Guid userId, CancellationToken ct = default)
    {
        var transaction = await db.Database.BeginTransactionAsync(ct);
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT set_config('app.current_user_id', {userId.ToString()}, true)", ct);
        return new PeopleTransaction(transaction);
    }

    public Task<Beneficiary?> GetBeneficiaryAsync(
        Guid id, Guid customerId, CancellationToken ct = default) =>
        db.Beneficiaries.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == customerId && x.DeletedAt == null, ct);

    public void AddBeneficiary(Beneficiary beneficiary) => db.Beneficiaries.Add(beneficiary);

    public Task<FamilyContact?> GetFamilyContactAsync(
        Guid id, Guid customerId, CancellationToken ct = default) =>
        db.FamilyContacts.SingleOrDefaultAsync(x =>
            x.Id == id && x.CustomerId == customerId && x.DeletedAt == null, ct);

    public Task<bool> FamilyPhoneExistsAsync(Guid customerId, string phoneNumber,
        Guid? excludedContactId, CancellationToken ct = default) =>
        db.FamilyContacts.AnyAsync(x => x.CustomerId == customerId &&
            x.PhoneNumber == phoneNumber &&
            (!excludedContactId.HasValue || x.Id != excludedContactId.Value) &&
            x.DeletedAt == null, ct);

    public void AddFamilyContact(FamilyContact contact) => db.FamilyContacts.Add(contact);

    public Task<CaregiverProfile?> GetCaregiverProfileByUserIdAsync(Guid userId,
        bool tracking = true, CancellationToken ct = default)
    {
        var query = tracking
            ? db.CaregiverProfiles.AsQueryable()
            : db.CaregiverProfiles.AsNoTracking();
        return query.SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
    }

    public Task<CaregiverProfile?> GetCaregiverProfileByIdAsync(
        Guid id, CancellationToken ct = default) =>
        db.CaregiverProfiles.SingleOrDefaultAsync(x => x.Id == id && x.DeletedAt == null, ct);

    public async Task<CaregiverProfileCreationResult> AddCaregiverProfileIdempotentlyAsync(
        CaregiverProfile profile, Guid userId, CancellationToken ct = default)
    {
        db.CaregiverProfiles.Add(profile);
        try
        {
            await db.SaveChangesAsync(ct);
            return new CaregiverProfileCreationResult(profile, true);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            var concurrentlyCreated = await db.CaregiverProfiles.AsNoTracking()
                .SingleOrDefaultAsync(x => x.UserId == userId && x.DeletedAt == null, ct);
            if (concurrentlyCreated is null) throw;

            return new CaregiverProfileCreationResult(concurrentlyCreated, false);
        }
    }

    public Task<string?> GetAvatarUrlAsync(Guid userId, CancellationToken ct = default) =>
        db.Database.SqlQueryRaw<string>(
                "SELECT avatar_url AS \"Value\" FROM identity.users WHERE id = {0}", userId)
            .FirstOrDefaultAsync(ct);

    public Task SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);

    private sealed class PeopleTransaction(IDbContextTransaction transaction) : IPeopleTransaction
    {
        public Task CommitAsync(CancellationToken ct = default) => transaction.CommitAsync(ct);
        public ValueTask DisposeAsync() => transaction.DisposeAsync();
    }
}
