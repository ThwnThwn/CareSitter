using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record AddBookingTimelineNoteCommand(
    Guid BookingId, string? Title, string? Note) : IRequest<Result<TimelineEventResponse>>;
