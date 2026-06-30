using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

/// <summary>media_assets dung cheo nhieu module -> expose qua interface, khong cho query truc tiep.</summary>
public interface IMediaService
{
    Task<Result<string>> CreateSignedUrlAsync(Guid mediaId, TimeSpan ttl, CancellationToken ct = default);
}

/// <summary>audit_logs dung cheo nhieu module -> ghi qua interface chung.</summary>
public interface IAuditLogger
{
    Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after,
        CancellationToken ct = default);
}
