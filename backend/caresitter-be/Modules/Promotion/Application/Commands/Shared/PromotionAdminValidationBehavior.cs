using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.Promotion.Application;

internal sealed class PromotionAdminValidationBehavior<TRequest, TValue>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, Result<TValue>> where TRequest : IRequest<Result<TValue>>
{
    public async Task<Result<TValue>> Handle(TRequest request,
        RequestHandlerDelegate<Result<TValue>> next, CancellationToken ct)
    {
        foreach (var validator in validators)
        {
            var validation = await validator.ValidateAsync(request, ct);
            if (!validation.IsValid)
                return Error.Validation("promotion.invalid_request", validation.Errors[0].ErrorMessage);
        }
        return await next();
    }
}
