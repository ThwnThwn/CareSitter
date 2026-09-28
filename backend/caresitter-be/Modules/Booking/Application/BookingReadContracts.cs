using System.Text.Json.Serialization;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

public sealed record BookingListResponse(
    IReadOnlyList<BookingResponse> Items, int Total, int Page, int PageSize,
    long SyncCursor = 0);

public sealed record BookingSyncResponse(
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    IReadOnlyList<BookingResponse>? Items,
    long NextCursor,
    DateTimeOffset ServerTime,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    bool? HasMore,
    bool ResetRequired);

public sealed record CaregiverSuggestionListResponse(
    IReadOnlyList<CaregiverSuggestionResponse> Items, int Total);

public sealed record ListBookingsQuery(string? Status, int Page = 1, int PageSize = 20)
    : IRequest<Result<BookingListResponse>>;
public sealed record GetBookingQuery(Guid BookingId)
    : IRequest<Result<BookingResponse>>;
public sealed record SyncBookingsQuery(long Cursor = 0)
    : IRequest<Result<BookingSyncResponse>>;
public sealed record GetCaregiverSuggestionsQuery(Guid BookingId, int Limit = 10)
    : IRequest<Result<CaregiverSuggestionListResponse>>;

internal enum BookingReadAudience
{
    Admin,
    Customer,
    Caregiver,
    OfferInbox
}

internal sealed record BookingPageCriteria(
    BookingReadAudience Audience,
    Guid? PrincipalId,
    IReadOnlyList<Guid>? BookingIds,
    BookingStatus? Status,
    int Page,
    int PageSize);

internal sealed record BookingPage(
    IReadOnlyList<Domain.Booking> Items, int Total);

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

internal sealed class BookingReadHandlers(
    IBookingReadStore store,
    ICurrentUser currentUser,
    IClock clock,
    IPeopleLookupService people,
    IMatchingService matching,
    IBookingSyncService bookingSync,
    IBookingResponseMapper responseMapper) :
    IRequestHandler<ListBookingsQuery, Result<BookingListResponse>>,
    IRequestHandler<GetBookingQuery, Result<BookingResponse>>,
    IRequestHandler<SyncBookingsQuery, Result<BookingSyncResponse>>,
    IRequestHandler<GetCaregiverSuggestionsQuery, Result<CaregiverSuggestionListResponse>>
{
    public async Task<Result<BookingListResponse>> Handle(
        ListBookingsQuery request, CancellationToken ct)
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
                bookingIds = await matching.GetOpenBookingIdsForCaregiverAsync(
                    caregiverId.Value, ct);
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
        var responses = await responseMapper.ToResponsesAsync(
            result.Items, ct, offerCaregiverId);
        return new BookingListResponse(responses, result.Total, page, pageSize, cursor);
    }

    public async Task<Result<BookingResponse>> Handle(
        GetBookingQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        var booking = await store.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();

        var canRead = booking.CustomerId == userId || currentUser.IsInRole("ADMIN");
        if (!canRead && currentUser.IsInRole("CAREGIVER"))
        {
            var caregiverId = await people.GetCaregiverProfileIdByUserIdAsync(userId, ct);
            canRead = caregiverId.HasValue &&
                (booking.CaregiverId == caregiverId.Value ||
                 await store.HasActiveCaregiverAccessAsync(
                     booking.Id, caregiverId.Value, clock.UtcNow, ct));
        }

        if (!canRead) return BookingErrors.Forbidden();
        return await responseMapper.ToResponseAsync(booking, ct);
    }

    public async Task<Result<BookingSyncResponse>> Handle(
        SyncBookingsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        if (!currentUser.IsInRole("CUSTOMER") && !currentUser.IsInRole("ADMIN"))
            return BookingErrors.Forbidden();

        var delta = await bookingSync.GetDeltaAsync(userId, request.Cursor, 100, ct);
        if (delta.ResetRequired)
            return new BookingSyncResponse(null, 0, clock.UtcNow, null, true);

        if (delta.Events.Count == 0)
            return new BookingSyncResponse([], delta.NextCursor, clock.UtcNow, false, false);

        var ids = delta.Events.Select(x => x.BookingId).Distinct().ToArray();
        var bookings = await store.GetManyAsync(ids, ct);
        var responses = await responseMapper.ToResponsesAsync(bookings, ct);
        return new BookingSyncResponse(
            responses, delta.NextCursor, clock.UtcNow, delta.HasMore, false);
    }

    public async Task<Result<CaregiverSuggestionListResponse>> Handle(
        GetCaregiverSuggestionsQuery request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingErrors.Unauthenticated();
        var booking = await store.GetAsync(request.BookingId, ct);
        if (booking is null) return BookingErrors.NotFound();
        if (booking.CustomerId != userId && !currentUser.IsInRole("ADMIN"))
            return BookingErrors.Forbidden();
        if (booking.CaregiverId.HasValue)
            return new CaregiverSuggestionListResponse([], 0);

        var limit = Math.Clamp(request.Limit, 1, 20);
        var candidates = await matching.GetSuggestedCaregiversAsync(request.BookingId, ct);
        var items = new List<CaregiverSuggestionResponse>();
        foreach (var candidate in candidates.Take(limit))
        {
            var display = await people.GetCaregiverDisplayAsync(candidate.CaregiverId, ct);
            items.Add(responseMapper.ToCaregiverSuggestion(candidate, display));
        }

        return new CaregiverSuggestionListResponse(items, candidates.Count);
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
