using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ListPaymentReconciliationQuery
    : IRequest<IReadOnlyList<PaymentReconciliationItem>>;
