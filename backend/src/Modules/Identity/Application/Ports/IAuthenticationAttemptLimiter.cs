using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IAuthenticationAttemptLimiter
{
    Task<bool> IsBlockedAsync(string scope, string subject, CancellationToken ct);
    Task<bool> RecordFailureAsync(string scope, string subject, int maxAttempts,
        TimeSpan window, TimeSpan blockDuration, CancellationToken ct);
    Task<bool> TryConsumeAsync(string scope, string subject, int limit,
        TimeSpan window, CancellationToken ct);
    Task ResetAsync(string scope, string subject, CancellationToken ct);
}
