namespace CareSitter.Contracts.Services;

/// <summary>
/// Booking-owned read seam used by the public service catalog.
/// </summary>
public interface IServiceChecklistReader
{
    Task<IReadOnlyList<PublicServiceChecklistItem>> ListActiveAsync(
        Guid serviceTypeId,
        CancellationToken ct = default);
}

public sealed record PublicServiceChecklistItem(
    Guid Id,
    Guid ServiceTypeId,
    string Name,
    string? Description,
    bool IsRequired,
    bool RequiresPhoto,
    int SortOrder);
