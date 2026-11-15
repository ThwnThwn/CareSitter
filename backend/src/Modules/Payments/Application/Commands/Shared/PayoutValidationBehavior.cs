using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Payments.Application.Payouts;

internal sealed class PayoutValidationBehavior<TRequest, TValue>(
    IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, Result<TValue>>
    where TRequest : IRequest<Result<TValue>>
{
    public async Task<Result<TValue>> Handle(
        TRequest request,
        RequestHandlerDelegate<Result<TValue>> next,
        CancellationToken ct)
    {
        if (!validators.Any())
            return await next();

        var context = new ValidationContext<TRequest>(request);
        var results = await Task.WhenAll(
            validators.Select(x => x.ValidateAsync(context, ct)));
        var failure = results
            .SelectMany(x => x.Errors)
            .FirstOrDefault(x => x is not null);

        return failure is null
            ? await next()
            : Error.Validation(failure.ErrorCode, failure.ErrorMessage);
    }
}
