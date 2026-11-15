namespace CareSitter.Contracts.Services;

public sealed record AdminQueueItem(
    string Type,
    Guid Id,
    string Title,
    string Subtitle,
    string Status,
    DateTimeOffset CreatedAt)
{
    public string Priority { get; init; } = "NORMAL";
}

public sealed record AdminStatusDescriptor(string Value, string Label, string Tone);

public sealed record AdminBookingSnapshot(
    int BookingsToday,
    IReadOnlyDictionary<string, int> StatusCounts);

public interface IAdminBookingReader
{
    Task<AdminBookingSnapshot> GetDashboardSnapshotAsync(
        DateTimeOffset scheduledFrom,
        DateTimeOffset scheduledUntil,
        CancellationToken ct = default);

    IReadOnlyList<AdminStatusDescriptor> GetStatusDescriptors();
}

public sealed record AdminPeopleSnapshot(int PendingKyc, IReadOnlyList<AdminQueueItem> WorkItems);

public interface IAdminPeopleReader
{
    Task<AdminPeopleSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default);
}

public sealed record AdminPaymentsSnapshot(
    int PendingPayouts,
    int ManualPayments,
    IReadOnlyList<AdminQueueItem> WorkItems);

public interface IAdminPaymentsReader
{
    Task<AdminPaymentsSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default);
}

public sealed record AdminSupportSnapshot(
    int OpenTickets,
    int OpenDisputes,
    IReadOnlyList<AdminQueueItem> WorkItems);

public interface IAdminSupportReader
{
    Task<AdminSupportSnapshot> GetDashboardSnapshotAsync(CancellationToken ct = default);
    IReadOnlyDictionary<string, string[]> GetTicketTransitions();
}

public sealed record AdminUserProfile(
    Guid Id,
    string Email,
    string? DisplayName,
    string? FullName,
    string[] Roles,
    string? Department);

public interface IAdminIdentityReader
{
    Task<int> CountActiveUsersAsync(CancellationToken ct = default);
    Task<AdminUserProfile?> FindUserAsync(Guid userId, CancellationToken ct = default);
}
