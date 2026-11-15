using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Contracts.Services;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingTrackingNotifier
{
    Task GpsUpdatedAsync(Guid customerId, GpsTrackResponse value, CancellationToken ct = default);
    Task TimelineAddedAsync(TimelineEventResponse timelineEvent, CancellationToken ct = default);
}
