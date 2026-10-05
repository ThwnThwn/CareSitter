using CareSitter.Modules.Payments.Application;

namespace CareSitter.Modules.Payments.Controllers;

public sealed record CreatePaymentIntentRequest(Guid BookingId);
