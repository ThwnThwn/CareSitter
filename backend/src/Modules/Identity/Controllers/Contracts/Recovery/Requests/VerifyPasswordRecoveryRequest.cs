namespace CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;

public sealed record VerifyPasswordRecoveryRequest(Guid ChallengeId, string Code);
