using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.AcceptBooking;
using CareSitter.Modules.Booking.Application.Commands.CancelBooking;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Commands.CompleteBooking;
using CareSitter.Modules.Booking.Application.Commands.CreateBooking;
using CareSitter.Modules.Booking.Application.Commands.DeclineBooking;
using CareSitter.Modules.Booking.Application.Commands.RaiseBookingSos;
using CareSitter.Modules.Booking.Application.Commands.RequestBookingCheckout;
using CareSitter.Modules.Booking.Application.Commands.RescheduleBooking;
using CareSitter.Modules.Booking.Application.Commands.SelectCaregiver;
using CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;
using CareSitter.Modules.Booking.Application.Commands.UploadCheckInSelfie;

namespace CareSitter.Modules.Booking.Controllers;

// ── DTOs ──
public sealed record CancelBookingRequest(string? Reason);
