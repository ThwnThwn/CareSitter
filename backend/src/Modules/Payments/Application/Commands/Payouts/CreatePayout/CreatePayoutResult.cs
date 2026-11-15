namespace CareSitter.Modules.Payments.Application.Payouts;

public sealed record CreatePayoutResult(PayoutResponse Payout, bool Created);
