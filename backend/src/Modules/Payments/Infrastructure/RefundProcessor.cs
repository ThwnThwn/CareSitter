using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class RefundProcessor(
    IRefundStore store,
    IVNPayRefundGateway gateway,
    IOptions<VNPayOptions> paymentOptions,
    IOptions<VNPayRefundOptions> refundOptions,
    ILogger<RefundProcessor> logger) : IRefundProcessor
{
    public async Task<int> ProcessPendingAsync(CancellationToken ct = default)
    {
        var options = refundOptions.Value;
        if (!options.Enabled) return 0;

        var processed = 0;
        while (processed < options.BatchSize && !ct.IsCancellationRequested)
        {
            var now = DateTimeOffset.UtcNow;
            var work = await store.ClaimNextAsync(
                now,
                now.AddSeconds(options.LeaseSeconds),
                now.AddSeconds(options.RetryDelaySeconds),
                ct);
            if (work is null) break;

            var wire = VNPayFullRefundRequest.Restore(
                work.Request.PaymentIntentId,
                work.Request.RequestId,
                paymentOptions.Value.TmnCode,
                work.Request.OriginalProviderOrderRef,
                work.Request.OriginalProviderTransactionId,
                work.Request.Amount,
                work.Request.OriginalProviderCreateDate,
                work.Request.RequestedAt,
                options.ServerIpAddress);
            RefundProviderResult providerResult;
            if (wire.IsFailure)
            {
                providerResult = new RefundProviderResult(
                    RefundProviderOutcome.Unknown,
                    ErrorCode: "INVALID_PERSISTED_SNAPSHOT");
            }
            else
            {
                providerResult = await SendAsync(work, wire.Value, ct);
            }

            var applied = await store.ApplyProviderResultAsync(
                work.Request.Id,
                work.LeaseId,
                providerResult,
                DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow.AddSeconds(options.RetryDelaySeconds),
                ct);
            if (applied.IsFailure)
            {
                logger.LogWarning(
                    "Could not persist provider refund result for {RefundRequestId}: {ErrorCode}",
                    work.Request.Id,
                    applied.Error.Code);
            }
            processed++;
        }

        return processed;
    }

    private async Task<RefundProviderResult> SendAsync(
        RefundWorkItem work,
        VNPayFullRefundRequest request,
        CancellationToken ct)
    {
        try
        {
            var result = work.Submit
                ? await gateway.SubmitAsync(request, ct)
                : await gateway.QueryAsync(
                    request,
                    $"RQ{Guid.NewGuid():N}"[..32],
                    DateTimeOffset.UtcNow,
                    ct);
            return new RefundProviderResult(
                result.State switch
                {
                    VNPayRefundState.Confirmed => RefundProviderOutcome.Confirmed,
                    VNPayRefundState.Processing => RefundProviderOutcome.Processing,
                    VNPayRefundState.Rejected => RefundProviderOutcome.Rejected,
                    _ => RefundProviderOutcome.Unknown
                },
                result.ProviderResponseId,
                result.ProviderRefundId,
                result.TransactionStatus,
                result.Code);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception,
                "VNPAY refund call ended ambiguously for {RefundRequestId}; the POST will not be repeated.",
                work.Request.Id);
            return new RefundProviderResult(
                RefundProviderOutcome.Unknown,
                ErrorCode: "TRANSPORT_UNKNOWN");
        }
    }
}
