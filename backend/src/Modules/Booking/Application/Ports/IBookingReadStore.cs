using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingReadStore
{
    Task<BookingPage> GetPageAsync(
        BookingPageCriteria criteria, CancellationToken ct = default);
    Task<Domain.Booking?> GetAsync(Guid bookingId, CancellationToken ct = default);
    Task<IReadOnlyList<Domain.Booking>> GetManyAsync(
        IReadOnlyCollection<Guid> bookingIds, CancellationToken ct = default);
    Task<bool> HasActiveCaregiverAccessAsync(
        Guid bookingId, Guid caregiverId, DateTimeOffset now,
        CancellationToken ct = default);
}
