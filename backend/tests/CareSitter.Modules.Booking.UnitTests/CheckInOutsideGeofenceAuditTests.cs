using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.CheckInBooking;
using CareSitter.Modules.Booking.Application.Sync;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class CheckInOutsideGeofenceAuditTests
{
    [Fact]
    public async Task Outside_geofence_is_rejected_but_persists_an_audit_timeline_event()
    {
        var now = new DateTimeOffset(2026, 10, 21, 8, 0, 0, TimeSpan.Zero);
        var booking = CreateEnRouteBooking(now.AddMinutes(15));
        var repository = new RecordingBookingRepository(booking);
        var options = Options.Create(new CheckInOptions
        {
            EarlyWindowMinutes = 30,
            MaxDistanceMeters = 50
        });
        var handler = new CheckInBookingCommandHandler(
            repository,
            new TestCurrentUser(Guid.NewGuid(), "CAREGIVER"),
            new AllowingPeopleLookup(),
            new FixedCatalogLookup((10.762622, 106.660172)),
            options,
            new CheckInBookingCommandValidator(options),
            new RecordingBookingSync(),
            new NoOpBookingChatWriter(),
            new ThrowingResponseMapper(),
            new TestClock(now));

        var result = await handler.Handle(new CheckInBookingCommand(
            booking.Id, 10.850000, 106.750000, 10), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.geofence", result.Error.Code);
        Assert.Equal(BookingStatus.CaregiverEnRoute, booking.Status);
        var audit = Assert.Single(repository.TimelineEvents);
        Assert.Equal("CHECKIN_OUTSIDE_GEOFENCE", audit.EventType);
        Assert.True(audit.DistanceToAddressMeters > 50);
        Assert.Equal(1, repository.SaveCount);
    }

    private static Domain.Booking CreateEnRouteBooking(DateTimeOffset start)
    {
        var booking = Domain.Booking.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), start,
            start.AddHours(2)).Value;
        var caregiverId = Guid.NewGuid();
        booking.SelectCaregiver(caregiverId);
        booking.TransitionTo(BookingStatus.PendingPayment);
        booking.TransitionTo(BookingStatus.Confirmed);
        booking.AssignCaregiver(caregiverId);
        booking.StartEnRoute();
        return booking;
    }

    private sealed class RecordingBookingRepository(Domain.Booking booking) : IBookingRepository
    {
        public List<CareTimelineEvent> TimelineEvents { get; } = [];
        public int SaveCount { get; private set; }

        public Task<Domain.Booking?> GetByIdAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult<Domain.Booking?>(booking.Id == bookingId ? booking : null);
        public Task<Domain.Booking?> GetByIdReadOnlyAsync(Guid bookingId, CancellationToken ct) => GetByIdAsync(bookingId, ct);
        public Task<Domain.Booking?> GetForCustomerAsync(Guid bookingId, Guid customerId, CancellationToken ct) => GetByIdAsync(bookingId, ct);
        public Task<bool> HasBeneficiaryScheduleConflictAsync(Guid bookingId, Guid beneficiaryId, DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) => Task.FromResult(false);
        public Task<bool> HasCaregiverScheduleConflictAsync(Guid bookingId, Guid caregiverId, DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) => Task.FromResult(false);
        public Task<List<CareTask>> GetPendingCareTasksAsync(Guid bookingId, CancellationToken ct) => Task.FromResult<List<CareTask>>([]);
        public Task<bool> HasPendingCareTasksAsync(Guid bookingId, CancellationToken ct) => Task.FromResult(false);
        public Task<bool> HasRequiredSkippedCareTasksAsync(Guid bookingId, CancellationToken ct) => Task.FromResult(false);
        public Task<List<CaregiverSlotHold>> GetActiveSlotHoldsAsync(Guid bookingId, CancellationToken ct) => Task.FromResult<List<CaregiverSlotHold>>([]);
        public Task<CaregiverSlotHold?> GetActiveSlotHoldAsync(Guid bookingId, CancellationToken ct) => Task.FromResult<CaregiverSlotHold?>(null);
        public Task<BookingAssignment?> GetActiveAssignmentReadOnlyAsync(Guid bookingId, Guid caregiverId, DateTimeOffset now, CancellationToken ct) => Task.FromResult<BookingAssignment?>(null);
        public Task<bool> HasAnyAssignmentAsync(Guid bookingId, CancellationToken ct) => Task.FromResult(false);
        public Task<BookingAssignment?> GetActiveAssignmentAsync(Guid bookingId, Guid caregiverId, CancellationToken ct) => Task.FromResult<BookingAssignment?>(null);
        public Task<List<BookingAssignment>> GetOtherOfferedAssignmentsAsync(Guid bookingId, Guid caregiverId, CancellationToken ct) => Task.FromResult<List<BookingAssignment>>([]);
        public Task<BookingAssignment?> GetAssignmentAsync(Guid bookingId, Guid caregiverId, CancellationToken ct) => Task.FromResult<BookingAssignment?>(null);
        public Task<bool> HasActiveOfferAsync(Guid bookingId, DateTimeOffset now, CancellationToken ct) => Task.FromResult(false);
        public void Add(Domain.Booking value) { }
        public void AddSlotHold(CaregiverSlotHold slotHold) { }
        public void AddAssignment(BookingAssignment assignment) { }
        public void AddTimelineEvent(CareTimelineEvent timelineEvent) => TimelineEvents.Add(timelineEvent);
        public Task SaveChangesAsync(CancellationToken ct) { SaveCount++; return Task.CompletedTask; }
        public Task<bool> TrySaveSlotHoldChangesAsync(CancellationToken ct) => Task.FromResult(true);
    }

    private sealed class TestCurrentUser(Guid userId, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) => roles.Contains(role, StringComparer.OrdinalIgnoreCase);
    }

    private sealed class TestClock(DateTimeOffset now) : IClock
    {
        public DateTimeOffset UtcNow => now;
    }

    private sealed class AllowingPeopleLookup : IPeopleLookupService
    {
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default) => Task.FromResult<Guid?>(null);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult<Guid?>(null);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
    }

    private sealed class FixedCatalogLookup((double Lat, double Lng) location) : ICatalogLookupService
    {
        public Task<(double Lat, double Lng)?> GetAddressLocationAsync(Guid addressId, CancellationToken ct = default) => Task.FromResult<(double, double)?>(location);
        public Task<bool> AddressBelongsToAsync(Guid addressId, Guid customerId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> AddressIsVerifiedForBookingAsync(Guid addressId, Guid customerId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<bool> ServiceIsActiveAsync(Guid serviceTypeId, CancellationToken ct = default) => Task.FromResult(true);
        public Task<AddressDisplaySummary?> GetAddressDisplayAsync(Guid addressId, CancellationToken ct = default) => Task.FromResult<AddressDisplaySummary?>(null);
        public Task<ServiceDisplaySummary?> GetServiceDisplayAsync(Guid serviceTypeId, CancellationToken ct = default) => Task.FromResult<ServiceDisplaySummary?>(null);
    }

    private sealed class RecordingBookingSync : IBookingSyncService
    {
        public void WriteSyncEvent(Domain.Booking booking, string eventType) => throw new InvalidOperationException("Rejected check-in must not write a success sync event.");
        public Task<long> GetCurrentCursorAsync(Guid customerId, CancellationToken ct = default) => Task.FromResult(0L);
        public Task<BookingSyncDeltaResult> GetDeltaAsync(Guid customerId, long afterCursor, int batchSize = 100, CancellationToken ct = default) => throw new NotSupportedException();
    }

    private sealed class NoOpBookingChatWriter : IBookingChatWriter
    {
        public Task EnsureFirstEpochAsync(Domain.Booking booking, Guid caregiverUserId, DateTimeOffset occurredAt, CancellationToken ct = default) => Task.CompletedTask;
        public Task RecordSystemTransitionAsync(Domain.Booking booking, string sourceEventType, string bodySnapshot, DateTimeOffset occurredAt, BookingChatTransitionEffect effect = BookingChatTransitionEffect.None, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class NoOpPostCommitService : IBookingPostCommitService
    {
        public Task RunAsync(string action, Func<Task> operation) => Task.CompletedTask;
        public Task BroadcastStatusAsync(Guid bookingId, string oldStatus, string newStatus, CancellationToken ct) => Task.CompletedTask;
        public Task BroadcastAcceptedStatusAsync(Domain.Booking booking, string oldStatus, CancellationToken ct) => Task.CompletedTask;
        public Task PublishCustomerSyncEventAsync(Domain.Booking booking, CancellationToken ct) => Task.CompletedTask;
        public Task NotifyBookingUserAsync(Guid userId, Domain.Booking booking, string title, string body, CancellationToken ct) => Task.CompletedTask;
        public Task NotifyCaregiverAsync(Domain.Booking booking, string title, string body, CancellationToken ct) => Task.CompletedTask;
        public Task NotifySosTargetsAsync(Domain.Booking booking, Guid raisedByUserId, CancellationToken ct) => Task.CompletedTask;
        public Task PublishOfferChangedAsync(Guid caregiverId, Guid bookingId, string changeType, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class ThrowingResponseMapper : IBookingResponseMapper
    {
        public Task<IReadOnlyList<BookingResponse>> ToResponsesAsync(IReadOnlyList<Domain.Booking> bookings, CancellationToken ct, Guid? offerCaregiverId = null) => throw new NotSupportedException();
        public Task<BookingResponse> ToResponseAsync(Domain.Booking booking, CancellationToken ct) => throw new InvalidOperationException("Rejected check-in must not map a success response.");
        public CaregiverSuggestionResponse ToCaregiverSuggestion(MatchingCandidate candidate, PeopleDisplaySummary? display) => throw new NotSupportedException();
    }
}
