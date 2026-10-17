using System.Security.Cryptography;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Payouts;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayoutProcessor(
    IPayoutStore store,
    IPayoutProvider provider,
    IEncryptionService encryption,
    IOptions<PayOSPayoutOptions> options,
    ILogger<PayoutProcessor> logger) : IPayoutProcessor
{
    public async Task<int> ProcessPendingAsync(CancellationToken ct = default)
    {
        var config = options.Value;
        if (!config.Enabled) return 0;

        var processed = 0;
        for (var index = 0; index < config.BatchSize; index++)
        {
            var now = DateTimeOffset.UtcNow;
            var nextCheckAt = now.AddSeconds(config.QueryDelaySeconds);
            var payout = await store.ClaimNextProviderWorkAsync(now, nextCheckAt, ct);
            if (payout is null) break;

            PayoutProviderResult result;
            try
            {
                var accountNumber = encryption.Decrypt(payout.AccountNumberEncrypted);
                var request = new PayoutProviderRequest(
                    payout.ProviderReferenceId,
                    $"payout-{payout.Id:N}",
                    payout.Amount,
                    $"CareSitter {payout.Id:N}"[..25],
                    payout.BankBin,
                    accountNumber);
                result = payout.ProviderPayoutId is null
                    ? await provider.CreateAsync(request, ct)
                    : await provider.QueryAsync(payout.ProviderPayoutId, request, ct);
            }
            catch (Exception exception) when (exception is FormatException or CryptographicException)
            {
                result = new PayoutProviderResult(
                    PayoutProviderOutcome.Failed,
                    "LOCAL_VALIDATION_FAILED",
                    ErrorCode: "ACCOUNT_DECRYPTION_FAILED");
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Unexpected payout provider failure for payout {PayoutId}.", payout.Id);
                result = new PayoutProviderResult(
                    PayoutProviderOutcome.Unknown,
                    "PROVIDER_UNKNOWN",
                    payout.ProviderPayoutId,
                    ErrorCode: "UNEXPECTED_PROVIDER_ERROR");
            }

            var applied = await store.ApplyProviderResultAsync(
                payout.Id, result, DateTimeOffset.UtcNow,
                DateTimeOffset.UtcNow.AddSeconds(config.QueryDelaySeconds), ct);
            if (applied.IsFailure)
                logger.LogWarning("Could not apply payout provider result for {PayoutId}: {Code}",
                    payout.Id, applied.Error.Code);
            processed++;
        }

        return processed;
    }
}
