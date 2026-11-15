namespace CareSitter.Modules.Identity.Application;

public sealed record RecoveryChallengeResponse(Guid ChallengeId, int ExpiresIn, int ResendAfter, string Message);
