using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Identity.Application;

public interface IPasswordRecoveryService
{
    Task<Result<RecoveryChallengeResponse>> RequestAsync(string email, CancellationToken ct);
    Task<Result<RecoveryGrantResponse>> VerifyAsync(Guid challengeId, string code, CancellationToken ct);
    Task<Result> ResetAsync(string token, string newPassword, CancellationToken ct);
    Task<Result<RecoveryChallengeResponse>> RequestEmailAsync(Guid userId, string? newEmail,
        string? currentPassword, CancellationToken ct);
    Task<Result<RecoveryEmailResponse>> ConfirmEmailAsync(Guid userId, Guid challengeId, string code,
        CancellationToken ct);
    Task<Result<string>> ChangePasswordAsync(Guid userId, string currentPassword, string newPassword,
        CancellationToken ct);
}
