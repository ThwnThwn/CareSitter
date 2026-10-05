namespace CareSitter.Modules.Payments.Application;

public enum PaymentFinalizationSource
{
    Ipn,
    ReturnFallback,
    RetryPreflight,
    ReconciliationJob,
    AdminManual
}
