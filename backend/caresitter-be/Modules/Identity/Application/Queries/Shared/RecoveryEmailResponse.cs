namespace CareSitter.Modules.Identity.Application;

public sealed record RecoveryEmailResponse(string Email, DateTimeOffset EmailVerifiedAt, bool SessionsRevoked);
