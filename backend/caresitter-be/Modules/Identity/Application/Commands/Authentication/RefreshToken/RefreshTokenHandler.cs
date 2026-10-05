using CareSitter.Modules.Identity.Application;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Identity.Application.RefreshToken;

/// <summary>
/// Rotates a persistent refresh-token session. PostgreSQL is authoritative;
/// Redis is only an optional lookup cache and is warmed after a cache miss.
/// </summary>
internal sealed class RefreshTokenHandler(IRefreshTokenSessionService sessions)
    : IRequestHandler<RefreshTokenCommand, Result<RefreshTokenResponse>>
{
    public async Task<Result<RefreshTokenResponse>> Handle(
        RefreshTokenCommand request,
        CancellationToken ct)
    {
        var result = await sessions.RotateAsync(request.RefreshToken, ct);
        if (result.IsFailure) return result.Error;

        return new RefreshTokenResponse(
            result.Value.AccessToken,
            result.Value.RefreshToken);
    }
}
