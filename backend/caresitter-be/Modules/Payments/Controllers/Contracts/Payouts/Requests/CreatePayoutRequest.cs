using CareSitter.Modules.Payments.Application.Payouts.ApprovePayout;
using CareSitter.Modules.Payments.Application.Payouts.CreatePayout;
using CareSitter.Modules.Payments.Application.Payouts.ListMyPayouts;
using CareSitter.Modules.Payments.Application.Payouts.ListPendingPayouts;
using CareSitter.Modules.Payments.Application.Payouts.RejectPayout;

namespace CareSitter.Modules.Payments.Controllers;

public sealed record CreatePayoutRequest(
    long Amount,
    string BankName,
    string AccountHolderName,
    string AccountNumber,
    string? IdempotencyKey = null);
