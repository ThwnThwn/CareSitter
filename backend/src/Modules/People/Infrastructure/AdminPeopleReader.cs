using CareSitter.Contracts.Services;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class AdminPeopleReader(PeopleDbContext db) : IAdminPeopleReader
{
    public async Task<AdminPeopleSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default)
    {
        var pendingKyc = await db.CaregiverProfiles.AsNoTracking()
            .CountAsync(x => x.DeletedAt == null && x.KycStatus == "PENDING", ct);

        var items = await db.CaregiverProfiles.AsNoTracking()
            .Where(x => x.DeletedAt == null && x.KycStatus == "PENDING")
            .OrderBy(x => x.UpdatedAt)
            .Take(5)
            .Select(x => new AdminQueueItem(
                "KYC",
                x.Id,
                "Hồ sơ KYC chờ duyệt",
                x.FullName ?? "Caregiver chưa cập nhật tên",
                "PENDING",
                x.UpdatedAt))
            .ToListAsync(ct);

        return new AdminPeopleSnapshot(pendingKyc, items);
    }
}
