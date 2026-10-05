using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IGoogleIdentityVerifier
{
    Task<Result<GoogleIdentity>> VerifyAsync(string idToken, CancellationToken ct = default);
}
