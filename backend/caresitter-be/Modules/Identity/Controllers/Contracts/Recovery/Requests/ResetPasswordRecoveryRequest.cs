namespace CareSitter.Modules.Identity.Controllers.Contracts.Recovery.Requests;

public sealed record ResetPasswordRecoveryRequest(string ResetToken, string NewPassword, string ConfirmPassword);
