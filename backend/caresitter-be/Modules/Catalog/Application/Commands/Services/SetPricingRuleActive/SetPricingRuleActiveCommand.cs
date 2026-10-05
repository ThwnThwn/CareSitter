using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record SetPricingRuleActiveCommand(
    Guid ServiceId,
    Guid RuleId,
    bool IsActive) : IRequest<Result<PricingRuleResponse>>;
