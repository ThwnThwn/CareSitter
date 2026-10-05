using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Payments.Application;

public sealed record PaymentIntentCreationOutcome(
    PaymentIntentResponse? Intent, bool Created, PaymentIntentConflict? Conflict = null);
