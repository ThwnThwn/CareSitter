using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentReconciliationItem(
    Guid IntentId,
    Guid BookingId,
    Guid CustomerId,
    long Amount,
    string Currency,
    string? ProviderOrderRef,
    string? ProviderTransactionId,
    int ReconciliationAttempts,
    DateTimeOffset? ReconciliationStartedAt,
    DateTimeOffset? LastReconciliationAt,
    string? LastReconciliationError,
    string? ManualReviewReason,
    string BookingStatus,
    DateTimeOffset? PaymentDeadline);

public sealed record ListPaymentReconciliationQuery
    : IRequest<IReadOnlyList<PaymentReconciliationItem>>;
public sealed record ResolvePaymentReviewCommand(
    Guid IntentId, bool Succeeded, string Reason, string? ProviderTransactionId)
    : IRequest<Result<PaymentReviewResolution>>;
public sealed record PaymentReviewResolution(
    PaymentFinalizationResult? Finalization,
    Guid? BookingId,
    string? Status);

public interface IPaymentReconciliationProcessor
{
    Task<IReadOnlyList<PaymentReconciliationItem>> ListAsync(CancellationToken ct = default);
    Task<Result<PaymentReviewResolution>> ResolveAsync(
        ResolvePaymentReviewCommand command, CancellationToken ct = default);
}

internal sealed class ListPaymentReconciliationQueryHandler(
    IPaymentReconciliationProcessor processor)
    : IRequestHandler<ListPaymentReconciliationQuery, IReadOnlyList<PaymentReconciliationItem>>
{
    public Task<IReadOnlyList<PaymentReconciliationItem>> Handle(
        ListPaymentReconciliationQuery request, CancellationToken ct) => processor.ListAsync(ct);
}

internal sealed class ResolvePaymentReviewCommandHandler(
    IPaymentReconciliationProcessor processor)
    : IRequestHandler<ResolvePaymentReviewCommand, Result<PaymentReviewResolution>>
{
    public Task<Result<PaymentReviewResolution>> Handle(
        ResolvePaymentReviewCommand request, CancellationToken ct) =>
        processor.ResolveAsync(request, ct);
}
