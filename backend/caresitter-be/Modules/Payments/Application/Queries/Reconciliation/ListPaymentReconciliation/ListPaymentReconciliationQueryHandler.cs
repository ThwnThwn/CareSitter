using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ListPaymentReconciliationQueryHandler(
    IPaymentReconciliationProcessor processor)
    : IRequestHandler<ListPaymentReconciliationQuery, IReadOnlyList<PaymentReconciliationItem>>
{
    public Task<IReadOnlyList<PaymentReconciliationItem>> Handle(
        ListPaymentReconciliationQuery request, CancellationToken ct) => processor.ListAsync(ct);
}
