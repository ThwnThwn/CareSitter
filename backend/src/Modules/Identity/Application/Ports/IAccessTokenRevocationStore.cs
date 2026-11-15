using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IAccessTokenRevocationStore
{
    Task RevokeAsync(string tokenId, TimeSpan ttl, CancellationToken ct = default);
}
