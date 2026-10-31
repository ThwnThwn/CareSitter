enum ServicePricingType { hourly, session, combo }

ServicePricingType classifyServicePricingType({
  required bool hasActivePlans,
  required bool hasPackagePlan,
}) {
  if (!hasActivePlans) return ServicePricingType.hourly;
  if (hasPackagePlan) return ServicePricingType.combo;
  return ServicePricingType.session;
}
