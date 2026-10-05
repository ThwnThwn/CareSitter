using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;

namespace CareSitter.Modules.Booking.Controllers;

public sealed record AddTimelineNoteRequest(string? Title, string? Note);
