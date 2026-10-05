using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class GetMyWalletQueryHandler(IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<GetMyWalletQuery, Result<WalletResponse>>
{
    public async Task<Result<WalletResponse>> Handle(GetMyWalletQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var type = currentUser.IsInRole("CAREGIVER") ? "CAREGIVER" : "CUSTOMER";
        return await portal.GetWalletAsync(userId, type, ct);
    }
}
