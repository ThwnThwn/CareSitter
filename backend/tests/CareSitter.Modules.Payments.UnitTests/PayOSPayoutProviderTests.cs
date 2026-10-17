using CareSitter.Modules.Payments.Application.Payouts;
using CareSitter.Modules.Payments.Infrastructure;
using PayOS.Models.V1.Payouts;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class PayOSPayoutProviderTests
{
    [Fact]
    public void SignedSucceededSnapshot_IsMappedToSucceeded()
    {
        var request = Request();
        var result = PayOSPayoutProvider.Map(Payout(
            PayoutApprovalState.Completed,
            PayoutTransactionState.Succeeded), request);

        Assert.Equal(PayoutProviderOutcome.Succeeded, result.Outcome);
        Assert.Equal("COMPLETED:SUCCEEDED", result.ProviderState);
        Assert.Equal("payout-id", result.ProviderPayoutId);
        Assert.Equal("bank-reference", result.ProviderTransactionId);
    }

    [Theory]
    [InlineData(PayoutApprovalState.Rejected, PayoutTransactionState.Failed)]
    [InlineData(PayoutApprovalState.Completed, PayoutTransactionState.Reversed)]
    public void TerminalFailureSnapshot_IsMappedToFailed(
        PayoutApprovalState approval,
        PayoutTransactionState transaction)
    {
        var result = PayOSPayoutProvider.Map(Payout(approval, transaction), Request());

        Assert.Equal(PayoutProviderOutcome.Failed, result.Outcome);
    }

    [Fact]
    public void DestinationMismatch_NeverConfirmsMoneyMovement()
    {
        var payout = Payout(PayoutApprovalState.Completed, PayoutTransactionState.Succeeded);
        payout.Transactions[0].Amount++;

        var result = PayOSPayoutProvider.Map(payout, Request());

        Assert.Equal(PayoutProviderOutcome.Unknown, result.Outcome);
        Assert.Equal("PROVIDER_TRANSACTION_MISMATCH", result.ErrorCode);
    }

    private static PayoutProviderRequest Request() => new(
        "CSreference",
        "payout-idempotency",
        100_000,
        "CareSitter payout",
        "970436",
        "0123456789");

    private static Payout Payout(
        PayoutApprovalState approval,
        PayoutTransactionState transaction) => new()
    {
        Id = "payout-id",
        ReferenceId = "CSreference",
        ApprovalState = approval,
        Transactions =
        [
            new PayoutTransaction
            {
                Id = "transaction-id",
                ReferenceId = "CSreference",
                Amount = 100_000,
                ToBin = "970436",
                ToAccountNumber = "0123456789",
                Reference = "bank-reference",
                State = transaction,
                ErrorCode = transaction == PayoutTransactionState.Failed
                    ? "DESTINATION_INVALID"
                    : null
            }
        ]
    };
}
