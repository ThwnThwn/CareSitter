using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class RefreshPaymentIntentCommandHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<RefreshPaymentIntentCommand, Result<PaymentIntentResponse>>
{
    public async Task<Result<PaymentIntentResponse>> Handle(
        RefreshPaymentIntentCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PaymentPortalErrors.Unauthenticated();
        // PayOS polling can update payment state before producing the response.
        var intent = await portal.GetIntentAsync(request.IntentId, userId, ct);
        return intent is null ? PaymentPortalErrors.NotFound() : intent;
    }
}
