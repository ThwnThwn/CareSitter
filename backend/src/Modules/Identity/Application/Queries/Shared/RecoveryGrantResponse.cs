namespace CareSitter.Modules.Identity.Application;

public sealed record RecoveryGrantResponse(string ResetToken, int ExpiresIn);
