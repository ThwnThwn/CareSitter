using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentPage<T>(IReadOnlyList<T> Items, int Total, int Page, int PageSize);
