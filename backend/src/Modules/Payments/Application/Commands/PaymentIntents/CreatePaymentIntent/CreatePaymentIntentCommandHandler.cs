using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class CreatePaymentIntentCommandHandler(
    IPaymentPortal portal, ICurrentUser currentUser)
    : IRequestHandler<CreatePaymentIntentCommand, Result<PaymentIntentCreationOutcome>>
{
    public Task<Result<PaymentIntentCreationOutcome>> Handle(
        CreatePaymentIntentCommand request, CancellationToken ct) =>
        currentUser.UserId is { } userId
            ? portal.CreateIntentAsync(request.BookingId, userId, request.CustomerName, ct, request.Provider)
            : Task.FromResult<Result<PaymentIntentCreationOutcome>>(
                PaymentPortalErrors.Unauthenticated());
}
