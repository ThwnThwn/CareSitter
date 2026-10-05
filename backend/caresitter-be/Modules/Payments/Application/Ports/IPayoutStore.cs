using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application.Payouts;

internal interface IPayoutStore
{
    Task<PayoutRequest?> FindExistingAsync(
        Guid caregiverId, string idempotencyKey, CancellationToken ct = default);
    Task<WalletAccount?> FindCaregiverWalletAsync(Guid userId, CancellationToken ct = default);
    Task<PayoutCreateStatus> CreateAsync(
        PayoutRequest payout, long amount, CancellationToken ct = default);
    Task<Result<PayoutRequest>> ApproveAsync(
        Guid payoutId, Guid adminId, CancellationToken ct = default);
    Task<Result<PayoutRequest>> RejectAsync(
        Guid payoutId, Guid adminId, string? reason, CancellationToken ct = default);
    Task<PayoutPage> ListForCaregiverAsync(
        Guid caregiverId, int page, int pageSize, PayoutMapper mapper,
        CancellationToken ct = default);
    Task<PayoutPage> ListForAdminAsync(
        string? status, int page, int pageSize, PayoutMapper mapper,
        CancellationToken ct = default);
}
