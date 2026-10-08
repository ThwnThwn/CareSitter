namespace CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;

public sealed record ConfirmRecoveryEmailRequest(Guid ChallengeId, string Code);
