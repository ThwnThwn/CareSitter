namespace CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;

public sealed record RequestRecoveryEmailRequest(string? NewEmail = null, string? CurrentPassword = null);
