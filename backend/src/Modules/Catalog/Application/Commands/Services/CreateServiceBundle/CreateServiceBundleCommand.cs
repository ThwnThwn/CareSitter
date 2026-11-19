using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Modules;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record CreateServiceBundleCommand(Guid RequestId, CreateServiceCommand Service,
    CreatePricingRuleCommand Price, IReadOnlyList<ServiceChecklistItem> Checklist)
    : IRequest<Result<AdminServiceResponse>>, IAtomicModuleCommand
{
    public string TransactionGroup => "catalog";
    public string LockKey => RequestId.ToString();
}
