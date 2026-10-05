using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentIntentConflict(
    string Error, string? Code = null,
    DateTimeOffset? PaymentDeadline = null, DateTimeOffset? ExpiresAt = null);
