using CareSitter.Modules.Catalog.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

internal static class CatalogAdminMapper
{
    public static AdminServiceResponse ToResponse(ServiceType service) => new(
        service.Id, service.Code, service.Name, service.Description, service.ImageUrl,
        service.DefaultDurationMinutes, service.IsActive, service.AllowAdHocTasks, [], []);

    public static PricingRuleResponse ToResponse(PricingRule rule) => new(
        rule.Id, rule.ServiceTypeId, rule.Name, rule.BaseHourlyPrice,
        rule.NightMultiplier, rule.HolidayMultiplier, rule.PlatformFeePercent,
        rule.DisputeWindowHours, rule.EffectiveFrom, rule.EffectiveTo, rule.IsActive);

    public static ServicePlanResponse ToResponse(ServicePlan plan) => new(
        plan.Id, plan.ServiceTypeId, plan.Code, plan.Name, plan.Description,
        plan.BillingUnit, plan.DurationMinutes, plan.IncludedSessions, plan.TotalPrice,
        plan.ValidityDays, plan.PlatformFeePercent, plan.DisputeWindowHours, plan.SortOrder,
        plan.EffectiveFrom, plan.EffectiveTo, plan.IsActive);
}
