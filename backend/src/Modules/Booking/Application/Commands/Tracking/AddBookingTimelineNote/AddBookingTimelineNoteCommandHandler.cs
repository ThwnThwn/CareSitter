using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class AddBookingTimelineNoteCommandHandler(
    IBookingTrackingStore store,
    IBookingTrackingNotifier notifier,
    ICurrentUser currentUser,
    IPeopleLookupService people)
    : IRequestHandler<AddBookingTimelineNoteCommand, Result<TimelineEventResponse>>
{
    public async Task<Result<TimelineEventResponse>> Handle(
        AddBookingTimelineNoteCommand request, CancellationToken ct)
    {
        var access = await BookingTrackingAccess.GetAuthorizedBookingAsync(
            request.BookingId, store, currentUser, people, ct);
        if (access.IsFailure) return access.Error;
        var timelineEvent = await store.AddTimelineNoteAsync(
            request.BookingId, access.Value.CaregiverId, request.Title, request.Note, ct);
        await notifier.TimelineAddedAsync(timelineEvent, ct);
        return timelineEvent;
    }
}
