using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ListPaymentReconciliationQuery(int Page = 1, int PageSize = 20)
    : IRequest<PaymentPage<PaymentReconciliationItem>>;
