using CareSitter.Contracts.Services;

namespace CareSitter.Modules.Catalog.Controllers;

public sealed record CreateServiceBundleRequest(Guid RequestId, UpsertServiceRequest Service,
    UpsertPricingRuleRequest Price, IReadOnlyList<ServiceChecklistItem> Checklist);
