using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

internal sealed class ListPaymentReconciliationQueryHandler(
    IPaymentReconciliationProcessor processor)
    : IRequestHandler<ListPaymentReconciliationQuery, PaymentPage<PaymentReconciliationItem>>
{
    public Task<PaymentPage<PaymentReconciliationItem>> Handle(
        ListPaymentReconciliationQuery request, CancellationToken ct) =>
        processor.ListAsync(request.Page, request.PageSize, ct);
}
