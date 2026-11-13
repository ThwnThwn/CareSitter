using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

internal sealed class FirebaseGoogleLoginHandler(IFirebaseGoogleIdentityVerifier verifier, GoogleAccountSignIn signIn)
    : IRequestHandler<FirebaseGoogleLoginCommand, Result<GoogleLoginResponse>>
{
    public async Task<Result<GoogleLoginResponse>> Handle(FirebaseGoogleLoginCommand request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.IdToken) || request.IdToken.Length > 16384)
            return Error.Validation("auth.firebase_token_required", "Firebase ID token không hợp lệ.");
        var identity = await verifier.VerifyAsync(request.IdToken, ct);
        return identity.IsFailure ? identity.Error
            : await signIn.SignInAsync(identity.Value, GoogleLoginRolePolicy.Customer, ct);
    }
}
