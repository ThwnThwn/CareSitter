using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IFirebaseGoogleIdentityVerifier
{
    Task<Result<GoogleIdentity>> VerifyAsync(string idToken, CancellationToken ct = default);
}
