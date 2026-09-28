using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>
/// Module-neutral boundary for booking-owned media persisted by Catalog.
/// </summary>
public interface IBookingMediaStore
{
    Task<Result<Guid>> AddPhotoAsync(
        Guid ownerUserId,
        Guid bookingId,
        string url,
        string mimeType,
        long sizeBytes,
        CancellationToken ct = default);

    Task<IReadOnlyDictionary<Guid, string>> GetUrlsAsync(
        IReadOnlyCollection<Guid> mediaIds,
        CancellationToken ct = default);
}

public interface IServiceChecklistCatalog
{
    Task<bool> ExistsAsync(Guid serviceTypeId, CancellationToken ct = default);
    Task<bool?> GetAllowAdHocTasksAsync(Guid serviceTypeId, CancellationToken ct = default);
    Task<ServiceChecklistPolicyChange?> SetPolicyAsync(
        Guid serviceTypeId, bool allowAdHocTasks, CancellationToken ct = default);
}

public sealed record ServiceChecklistPolicyChange(
    Guid ServiceTypeId, bool PreviousAllowAdHocTasks, bool AllowAdHocTasks);
