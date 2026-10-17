using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts.CreatePayout;

internal sealed class CreatePayoutCommandHandler(
    IPayoutStore store,
    ICurrentUser currentUser,
    IEncryptionService encryption,
    IAuditLogger auditLogger,
    PayoutMapper mapper)
    : IRequestHandler<CreatePayoutCommand, Result<CreatePayoutResult>>
{
    public async Task<Result<CreatePayoutResult>> Handle(
        CreatePayoutCommand request,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return PayoutErrors.Unauthenticated();

        var idempotencyKey = request.ResolveIdempotencyKey()!;
        var existing = await store.FindExistingAsync(userId, idempotencyKey, ct);
        if (existing is not null)
            return new CreatePayoutResult(mapper.ToResponse(existing), Created: false);

        var wallet = await store.FindCaregiverWalletAsync(userId, ct);
        if (wallet is null)
            return PayoutErrors.WalletNotFound();

        var payout = PayoutRequest.Create(
            userId,
            wallet.Id,
            idempotencyKey,
            request.Amount,
            request.BankName,
            request.BankBin,
            request.AccountHolderName,
            encryption.Encrypt(request.AccountNumber.Trim()));
        if (payout.IsFailure)
            return payout.Error;

        var persisted = await store.CreateAsync(payout.Value, request.Amount, ct);
        if (persisted != PayoutCreateStatus.Created)
        {
            existing = await store.FindExistingAsync(userId, idempotencyKey, ct);
            if (existing is not null)
                return new CreatePayoutResult(mapper.ToResponse(existing), Created: false);
            return PayoutErrors.InsufficientBalance();
        }

        await auditLogger.WriteAsync(
            "PAYOUT_REQUEST_CREATED",
            "PayoutRequest",
            payout.Value.Id,
            null,
            new
            {
                payout.Value.CaregiverId,
                payout.Value.WalletAccountId,
                payout.Value.Amount,
                payout.Value.Status
            },
            ct);

        return new CreatePayoutResult(mapper.ToResponse(payout.Value), Created: true);
    }
}
