using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Payouts;
using Microsoft.Extensions.Options;
using PayOS.Exceptions;
using PayOS.Models;
using PayOS.Models.V1.Payouts;
using ProviderPayout = PayOS.Models.V1.Payouts.Payout;
using ProviderPayoutRequest = PayOS.Models.V1.Payouts.PayoutRequest;

namespace CareSitter.Modules.Payments.Infrastructure;

internal sealed class PayOSPayoutProvider : IPayoutProvider, IDisposable
{
    private readonly global::PayOS.PayOSClient _client;

    public PayOSPayoutProvider(HttpClient httpClient, IOptions<PayOSPayoutOptions> options)
    {
        var config = options.Value;
        _client = new global::PayOS.PayOSClient(new global::PayOS.PayOSOptions
        {
            ClientId = config.ClientId,
            ApiKey = config.ApiKey,
            ChecksumKey = config.ChecksumKey,
            BaseUrl = "https://api-merchant.payos.vn",
            TimeoutMs = 10_000,
            MaxRetries = 2,
            HttpClient = httpClient
        });
    }

    public async Task<PayoutProviderResult> CreateAsync(
        PayoutProviderRequest request,
        CancellationToken ct = default)
    {
        try
        {
            var created = await _client.Payouts.CreateAsync(
                ToProviderRequest(request),
                request.IdempotencyKey,
                new RequestOptions<ProviderPayout> { CancellationToken = ct });
            return Map(created, request);
        }
        catch (ApiException exception) when (exception.StatusCode is 400 or 401 or 403)
        {
            return Rejected(exception);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (exception is ApiException or PayOSException or HttpRequestException)
        {
            return Unknown(exception);
        }
    }

    public async Task<PayoutProviderResult> QueryAsync(
        string providerPayoutId,
        PayoutProviderRequest expected,
        CancellationToken ct = default)
    {
        try
        {
            var payout = await _client.Payouts.GetAsync(
                providerPayoutId,
                new RequestOptions { CancellationToken = ct });
            return Map(payout, expected);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception) when (exception is ApiException or PayOSException or HttpRequestException)
        {
            return Unknown(exception, providerPayoutId);
        }
    }

    internal static PayoutProviderResult Map(
        ProviderPayout payout,
        PayoutProviderRequest expected)
    {
        if (string.IsNullOrWhiteSpace(payout.Id) ||
            !string.Equals(payout.ReferenceId, expected.ReferenceId, StringComparison.Ordinal) ||
            payout.Transactions.Count != 1)
        {
            return new PayoutProviderResult(
                PayoutProviderOutcome.Unknown,
                "RESPONSE_MISMATCH",
                ErrorCode: "PROVIDER_REFERENCE_MISMATCH");
        }

        var transaction = payout.Transactions[0];
        if (!string.Equals(transaction.ReferenceId, expected.ReferenceId, StringComparison.Ordinal) ||
            transaction.Amount != expected.Amount ||
            !string.Equals(transaction.ToBin, expected.BankBin, StringComparison.Ordinal) ||
            !string.Equals(transaction.ToAccountNumber, expected.AccountNumber, StringComparison.Ordinal))
        {
            return new PayoutProviderResult(
                PayoutProviderOutcome.Unknown,
                "RESPONSE_MISMATCH",
                payout.Id,
                ErrorCode: "PROVIDER_TRANSACTION_MISMATCH");
        }

        var approval = PayoutApprovalStateConverter.ToSerializedString(payout.ApprovalState);
        var transactionState = PayoutTransactionStateConverter.ToSerializedString(transaction.State);
        var providerState = $"{approval}:{transactionState}";
        var transactionId = string.IsNullOrWhiteSpace(transaction.Reference)
            ? transaction.Id
            : transaction.Reference;
        var errorCode = NormalizeCode(transaction.ErrorCode);

        if (payout.ApprovalState == PayoutApprovalState.Completed &&
            transaction.State == PayoutTransactionState.Succeeded)
        {
            return new PayoutProviderResult(
                PayoutProviderOutcome.Succeeded,
                providerState,
                payout.Id,
                transactionId);
        }

        if (payout.ApprovalState is PayoutApprovalState.Rejected or
                PayoutApprovalState.Cancelled or PayoutApprovalState.Failed ||
            transaction.State is PayoutTransactionState.Cancelled or
                PayoutTransactionState.Reversed or PayoutTransactionState.Failed)
        {
            return new PayoutProviderResult(
                PayoutProviderOutcome.Failed,
                providerState,
                payout.Id,
                transactionId,
                errorCode ?? transactionState);
        }

        return new PayoutProviderResult(
            PayoutProviderOutcome.Processing,
            providerState,
            payout.Id,
            transactionId,
            errorCode);
    }

    private static ProviderPayoutRequest ToProviderRequest(PayoutProviderRequest request) => new()
    {
        ReferenceId = request.ReferenceId,
        Amount = request.Amount,
        Description = request.Description,
        ToBin = request.BankBin,
        ToAccountNumber = request.AccountNumber,
        Category = ["salary"]
    };

    private static PayoutProviderResult Rejected(ApiException exception) => new(
        PayoutProviderOutcome.Failed,
        $"HTTP_{exception.StatusCode}",
        ErrorCode: NormalizeCode(exception.ErrorCode) ?? $"HTTP_{exception.StatusCode}");

    private static PayoutProviderResult Unknown(
        Exception exception,
        string? providerPayoutId = null)
    {
        var code = exception is ApiException api
            ? NormalizeCode(api.ErrorCode) ?? (api.StatusCode is null ? null : $"HTTP_{api.StatusCode}")
            : exception is InvalidSignatureException
                ? "INVALID_SIGNATURE"
                : "TRANSPORT_UNKNOWN";
        return new PayoutProviderResult(
            PayoutProviderOutcome.Unknown,
            "PROVIDER_UNKNOWN",
            providerPayoutId,
            ErrorCode: code ?? "PROVIDER_UNKNOWN");
    }

    private static string? NormalizeCode(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var normalized = new string(value.Where(character =>
            char.IsAsciiLetterOrDigit(character) || character is '_' or '-').Take(100).ToArray());
        return normalized.Length == 0 ? null : normalized;
    }

    public void Dispose() => _client.Dispose();
}
