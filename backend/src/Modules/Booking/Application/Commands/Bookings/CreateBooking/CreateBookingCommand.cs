using CareSitter.SharedKernel.Results;
using MediatR;
using System.Text.Json.Serialization;

namespace CareSitter.Modules.Booking.Application.Commands.CreateBooking;

public sealed record CreateBookingCommand(
    Guid BeneficiaryId,
    Guid AddressId,
    Guid ServiceTypeId,
    DateTimeOffset ScheduledStart,
    DateTimeOffset ScheduledEnd,
    Guid? CaregiverId = null,
    IReadOnlyList<string>? RequiredSkills = null,
    string? PromotionCode = null,
    [property: JsonIgnore] Guid IdempotencyKey = default) : IRequest<Result<BookingResponse>>;
