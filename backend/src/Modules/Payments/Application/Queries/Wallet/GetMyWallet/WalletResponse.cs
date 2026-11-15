using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record WalletResponse(
    Guid? Id, long AvailableBalance, long PendingBalance, string Currency);
