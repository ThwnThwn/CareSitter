using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IOtpStore
{
    Task<string?> GetAsync(string email, CancellationToken ct = default);
    Task<bool> IsCoolingDownAsync(string email, CancellationToken ct = default);
    Task SaveAsync(string email, string code, TimeSpan ttl, TimeSpan cooldown,
        CancellationToken ct = default);
    Task RemoveAsync(string email, CancellationToken ct = default);
}
