using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application.CreateBooking;

public sealed record CreateBookingCommand(
    Guid BeneficiaryId,
    Guid AddressId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    Guid? CaregiverId = null,
    IReadOnlyList<string>? RequiredSkills = null) : IRequest<Result<Guid>>;
