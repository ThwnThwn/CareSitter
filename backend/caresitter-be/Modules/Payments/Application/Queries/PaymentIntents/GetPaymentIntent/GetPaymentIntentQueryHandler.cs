using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class GetPaymentIntentQueryHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<GetPaymentIntentQuery, Result<PaymentIntentResponse>>
{
    public async Task<Result<PaymentIntentResponse>> Handle(
        GetPaymentIntentQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        var intent = await portal.GetIntentAsync(request.IntentId, userId, ct);
        return intent is null ? PaymentPortalErrors.NotFound() : intent;
    }
}
