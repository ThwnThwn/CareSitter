using CareSitter.SharedKernel.Results;
using System.IO;

namespace CareSitter.Contracts.Services;

/// <summary>media_assets dung cheo nhieu module -> expose qua interface, khong cho query truc tiep.</summary>
public interface IMediaService
{
    /// <summary>KYC-only scoped API URI. Extract fragment ticket into X-Kyc-Read-Ticket;
    /// JWT remains mandatory. Prefer /media/{id}/access for structured grants.</summary>
    Task<Result<string>> CreateSignedUrlAsync(Guid mediaId, TimeSpan ttl, CancellationToken ct = default);
    Task<Result<string>> UploadImageAsync(Stream fileStream, string fileName, string folder, CancellationToken ct = default);
}

/// <summary>audit_logs dung cheo nhieu module -> ghi qua interface chung.</summary>
public interface IAuditLogger
{
    Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after,
        CancellationToken ct = default);
}
