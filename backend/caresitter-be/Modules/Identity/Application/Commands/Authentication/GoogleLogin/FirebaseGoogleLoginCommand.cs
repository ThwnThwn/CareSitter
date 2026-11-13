using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

public sealed record FirebaseGoogleLoginCommand(string IdToken) : IRequest<Result<GoogleLoginResponse>>;
