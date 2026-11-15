using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application.RefreshToken;

public sealed record RefreshTokenResponse(string AccessToken, string RefreshToken);
