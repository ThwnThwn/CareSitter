using CareSitter.Modules.Identity.Application;
using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

internal sealed class GoogleLoginHandler(IGoogleIdentityVerifier verifier, GoogleAccountSignIn signIn)
    : IRequestHandler<GoogleLoginCommand, Result<GoogleLoginResponse>>
{
    public async Task<Result<GoogleLoginResponse>> Handle(GoogleLoginCommand request, CancellationToken ct)
    {
        var role = GoogleLoginRolePolicy.Validate(request.RequiredRole);
        if (role.IsFailure) return role.Error;
        if (string.IsNullOrWhiteSpace(request.IdToken))
            return Error.Validation("auth.google_token_required", "Google ID Token là bắt buộc.");
        var verified = await verifier.VerifyAsync(request.IdToken, ct);
        return verified.IsFailure ? verified.Error : await signIn.SignInAsync(verified.Value, role.Value, ct);
    }
}
