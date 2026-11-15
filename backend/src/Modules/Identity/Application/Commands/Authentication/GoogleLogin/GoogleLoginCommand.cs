using CareSitter.Modules.Identity.Application.Login;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.GoogleLogin;

/// <summary>
/// Command nội bộ. RequiredRole luôn do controller gán cứng, không bind từ request body.
/// </summary>
public sealed record GoogleLoginCommand(
    string IdToken,
    string RequiredRole
) : IRequest<Result<GoogleLoginResponse>>;
