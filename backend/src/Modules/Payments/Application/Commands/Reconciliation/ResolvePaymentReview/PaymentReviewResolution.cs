using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentReviewResolution(
    PaymentFinalizationResult? Finalization,
    Guid? BookingId,
    string? Status);
