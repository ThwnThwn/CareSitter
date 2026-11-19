using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

public sealed record ServiceChecklistItem(string Name, string? Description, bool IsRequired, bool RequiresPhoto, int SortOrder);
public interface IServiceChecklistWriter
{
    Task<Result> AddItemAsync(Guid serviceId, ServiceChecklistItem item, CancellationToken ct);
}
