using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record CreatePaymentIntentCommand(Guid BookingId, string? CustomerName, string Provider = "VNPAY")
    : IRequest<Result<PaymentIntentCreationOutcome>>;
