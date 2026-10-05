using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class ListBookingsQueryHandler(
    IBookingReadStore store,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IMatchingService matching,
    IBookingSyncService bookingSync,
    IBookingResponseMapper responseMapper)
    : IRequestHandler<ListBookingsQuery, Result<BookingListResponse>>
{
    public async Task<Result<BookingListResponse>> Handle(ListBookingsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();

        var page = Math.Max(request.Page, 1);
        var pageSize = Math.Clamp(request.PageSize, 1, 50);
        var isAdmin = currentUser.IsInRole("ADMIN");
        var isCaregiver = !isAdmin && currentUser.IsInRole("CAREGIVER");
        if (IsOfferInbox(request.Status) && !isCaregiver)
            return BookingErrors.InvalidStatus();
        var status = ParseStatus(request.Status);
        if (status.IsFailure) return status.Error;

        var audience = BookingReadAudience.Customer;
        Guid? principalId = userId;
        IReadOnlyList<Guid>? bookingIds = null;
        Guid? offerCaregiverId = null;

        if (isAdmin)
        {
            audience = BookingReadAudience.Admin;
            principalId = null;
        }
        else if (isCaregiver)
        {
            var caregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            if (caregiverId is null)
                return new BookingListResponse([], 0, page, pageSize);

            principalId = caregiverId;
            if (IsOfferInbox(request.Status))
            {
                audience = BookingReadAudience.OfferInbox;
                bookingIds = await matching.GetOpenBookingIdsForCaregiverAsync(caregiverId.Value, ct);
                offerCaregiverId = caregiverId;
                status = Result.Success<BookingStatus?>(null);
            }
            else
            {
                audience = BookingReadAudience.Caregiver;
            }
        }

        var cursor = currentUser.IsInRole("CUSTOMER")
            ? await bookingSync.GetCurrentCursorAsync(userId, ct)
            : 0L;
        var result = await store.GetPageAsync(new BookingPageCriteria(
            audience, principalId, bookingIds, status.Value, page, pageSize), ct);
        var responses = await responseMapper.ToResponsesAsync(result.Items, ct, offerCaregiverId);
        return new BookingListResponse(responses, result.Total, page, pageSize, cursor);
    }

    private static bool IsOfferInbox(string? status) =>
        string.Equals(status, "open", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(status, "available", StringComparison.OrdinalIgnoreCase);

    private static Result<BookingStatus?> ParseStatus(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || IsOfferInbox(value))
            return Result.Success<BookingStatus?>(null);
        return Enum.TryParse<BookingStatus>(value.Replace("_", string.Empty), true, out var status)
            ? Result.Success<BookingStatus?>(status)
            : BookingErrors.InvalidStatus();
    }
}
