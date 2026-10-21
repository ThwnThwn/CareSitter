using CareSitter.Modules.Booking.Application.Bookings.Dtos.Requests;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;

namespace CareSitter.Modules.Booking.Application.Bookings.Mapping;

public static class BookingRequestMapper
{
    // Kept for DTO-boundary tests and non-HTTP mapping. HTTP creation must pass
    // the validated Idempotency-Key through the overload below.
    public static CreateBookingCommand ToCommand(this CreateBookingRequest request) =>
        request.ToCommand(Guid.Empty);

    public static CreateBookingCommand ToCommand(this CreateBookingRequest request, Guid idempotencyKey) =>
        new(request.BeneficiaryId, request.AddressId, request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, request.CaregiverId,
            request.RequiredSkills, request.PromotionCode, idempotencyKey);
}
