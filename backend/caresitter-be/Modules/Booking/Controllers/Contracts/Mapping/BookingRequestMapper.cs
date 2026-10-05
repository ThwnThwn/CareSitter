using CareSitter.Modules.Booking.Application.Bookings.Dtos.Requests;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;

namespace CareSitter.Modules.Booking.Application.Bookings.Mapping;

public static class BookingRequestMapper
{
    public static CreateBookingCommand ToCommand(this CreateBookingRequest request) =>
        new(request.BeneficiaryId, request.AddressId, request.ServiceTypeId,
            request.ScheduledStart, request.ScheduledEnd, request.CaregiverId,
            request.RequiredSkills, request.PromotionCode);
}
