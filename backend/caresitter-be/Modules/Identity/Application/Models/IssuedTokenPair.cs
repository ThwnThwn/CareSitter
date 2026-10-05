using CareSitter.Modules.Identity.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public sealed record IssuedTokenPair(string AccessToken, string RefreshToken);
