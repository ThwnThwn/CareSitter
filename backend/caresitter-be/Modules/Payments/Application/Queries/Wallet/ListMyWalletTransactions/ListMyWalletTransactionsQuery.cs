using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Payments.Application;

public sealed record ListMyWalletTransactionsQuery(int Page, int PageSize)
    : IRequest<Result<PaymentPage<WalletTransactionResponse>>>;
