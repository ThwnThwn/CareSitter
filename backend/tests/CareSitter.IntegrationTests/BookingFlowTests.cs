using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.CreateReview;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;

namespace CareSitter.IntegrationTests;

public sealed class BookingFlowTests
{
    [Fact]
    public void GoldenFlow_ReachesCompletedOnlyAfterPaymentOfferCheckInAndCheckout()
    {
        var customerId = Guid.NewGuid();
        var caregiverId = Guid.NewGuid();
        var caregiverUserId = Guid.NewGuid();
        var start = DateTimeOffset.UtcNow.AddHours(2);
        var booking = CareSitter.Modules.Booking.Domain.Booking.Create(
            customerId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            start,
            start.AddHours(4)).Value;

        Assert.True(booking.ApplyPricing(
            escrow: 500_000,
            platformFee: 75_000,
            caregiverEarning: 425_000,
            disputeWindowHours: 48).IsSuccess);
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        Assert.True(booking.ConfirmPayment().IsSuccess);

        var offer = BookingAssignment.CreateOffered(
            booking.Id,
            caregiverId,
            rank: 1,
            distanceMeters: 1_200,
            score: 0.95m,
            scoreBreakdown: "{\"distance\":1}",
            offeredAt: DateTimeOffset.UtcNow,
            expiresAt: DateTimeOffset.UtcNow.AddMinutes(5));
        offer.Accept();
        Assert.Equal("ACCEPTED", offer.Status);
        Assert.True(booking.AssignCaregiver(caregiverId).IsSuccess);
        Assert.True(booking.StartEnRoute().IsSuccess);

        var address = new GeoPoint(10.762622, 106.660172);
        Assert.True(booking.CheckIn(
            address,
            address,
            checkedInAt: start.AddMinutes(-15)).IsSuccess);

        var requiredTask = CareTask.Create(
            booking.Id,
            "Đo huyết áp",
            isRequired: true,
            requiresPhoto: true);
        requiredTask.MarkCompleted(caregiverUserId);
        Assert.Equal("COMPLETED", requiredTask.Status);

        Assert.True(booking.RequestManualCheckout().IsSuccess);
        Assert.True(booking.Complete().IsSuccess);
        Assert.Equal(BookingStatus.Completed, booking.Status);
        Assert.Null(booking.SettlementReleasedAt);
        Assert.Equal(48, booking.DisputeWindowHours);
    }

    [Fact]
    public async Task Review_RequiresCompletedBookingOwnedByCustomer()
    {
        var ownerId = Guid.NewGuid();
        var bookingId = Guid.NewGuid();
        var caregiverId = Guid.NewGuid();
        var repository = new SupportRepositoryStub();
        var command = new CreateReviewCommand(
            bookingId, caregiverId, 5, "Tận tâm", "[\"Dung gio\"]");

        var otherCustomer = new CreateReviewCommandHandler(
            repository,
            new CurrentUserStub(Guid.NewGuid(), "CUSTOMER"),
            new ReviewLookupStub(new ReviewableBooking(
                bookingId, ownerId, caregiverId, IsCompleted: true)),
            new CreateReviewCommandValidator());
        var forbidden = await otherCustomer.Handle(command, CancellationToken.None);
        Assert.Equal("support.forbidden", forbidden.Error.Code);

        var incompleteHandler = new CreateReviewCommandHandler(
            repository,
            new CurrentUserStub(ownerId, "CUSTOMER"),
            new ReviewLookupStub(new ReviewableBooking(
                bookingId, ownerId, caregiverId, IsCompleted: false)),
            new CreateReviewCommandValidator());
        var incomplete = await incompleteHandler.Handle(command, CancellationToken.None);
        Assert.Equal("support.review.booking_not_completed", incomplete.Error.Code);

        var ownerHandler = new CreateReviewCommandHandler(
            repository,
            new CurrentUserStub(ownerId, "CUSTOMER"),
            new ReviewLookupStub(new ReviewableBooking(
                bookingId, ownerId, caregiverId, IsCompleted: true)),
            new CreateReviewCommandValidator());
        var created = await ownerHandler.Handle(command, CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error.Message);
        Assert.Equal(ownerId, created.Value.CustomerId);
        Assert.Equal(caregiverId, created.Value.CaregiverId);
        Assert.Single(repository.Reviews);
    }

    [Fact]
    public async Task Dispute_RejectsCaregiverAndNonOwner()
    {
        var ownerId = Guid.NewGuid();
        var bookingId = Guid.NewGuid();
        var snapshot = Snapshot(bookingId, ownerId);

        var caregiver = new CreateDisputeCommandHandler(
            new SupportRepositoryStub(),
            new CurrentUserStub(Guid.NewGuid(), "CAREGIVER"),
            new DisputeWorkflowStub(snapshot));
        var caregiverResult = await caregiver.Handle(
            new CreateDisputeCommand(bookingId, "reason", null), CancellationToken.None);
        Assert.Equal("support.forbidden", caregiverResult.Error.Code);

        var otherCustomer = new CreateDisputeCommandHandler(
            new SupportRepositoryStub(),
            new CurrentUserStub(Guid.NewGuid(), "CUSTOMER"),
            new DisputeWorkflowStub(snapshot));
        var otherResult = await otherCustomer.Handle(
            new CreateDisputeCommand(bookingId, "reason", null), CancellationToken.None);
        Assert.Equal("support.forbidden", otherResult.Error.Code);
    }

    [Fact]
    public async Task Dispute_OwnerCanOpenWithinWindow_AndBookingMovesToDisputed()
    {
        var ownerId = Guid.NewGuid();
        var bookingId = Guid.NewGuid();
        var repository = new SupportRepositoryStub();
        var workflow = new DisputeWorkflowStub(Snapshot(bookingId, ownerId));
        var handler = new CreateDisputeCommandHandler(
            repository,
            new CurrentUserStub(ownerId, "CUSTOMER"),
            workflow);

        var result = await handler.Handle(
            new CreateDisputeCommand(bookingId, "Sai checklist", "Thiếu bằng chứng"),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Message);
        Assert.True(workflow.OpenCalled);
        Assert.Single(repository.Disputes);
        Assert.Equal("OPEN", repository.Disputes[0].Status);
    }

    [Fact]
    public async Task Dispute_CompletedBookingOutsideWindow_IsRejected()
    {
        var ownerId = Guid.NewGuid();
        var bookingId = Guid.NewGuid();
        var expired = Snapshot(bookingId, ownerId) with
        {
            ActualEnd = DateTimeOffset.UtcNow.AddHours(-49),
            DisputeWindowHours = 48
        };
        var handler = new CreateDisputeCommandHandler(
            new SupportRepositoryStub(),
            new CurrentUserStub(ownerId, "CUSTOMER"),
            new DisputeWorkflowStub(expired));

        var result = await handler.Handle(
            new CreateDisputeCommand(bookingId, "late", null), CancellationToken.None);

        Assert.Equal("support.dispute.window_expired", result.Error.Code);
    }

    private static DisputeBookingSnapshot Snapshot(Guid bookingId, Guid customerId) => new(
        bookingId,
        customerId,
        Guid.NewGuid(),
        Guid.NewGuid(),
        "completed",
        100_000,
        15_000,
        48,
        DateTimeOffset.UtcNow.AddHours(-1),
        null);

    private sealed class CurrentUserStub(Guid? userId, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) =>
            roles.Contains(role, StringComparer.OrdinalIgnoreCase);
    }

    private sealed class ReviewLookupStub(ReviewableBooking? booking) : IReviewBookingLookup
    {
        public Task<ReviewableBooking?> GetForReviewAsync(
            Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(booking?.BookingId == bookingId ? booking : null);
    }

    private sealed class DisputeWorkflowStub(DisputeBookingSnapshot? booking)
        : IDisputeBookingWorkflow
    {
        public bool OpenCalled { get; private set; }

        public Task<DisputeBookingSnapshot?> GetAsync(
            Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(booking?.BookingId == bookingId ? booking : null);

        public Task<Result> OpenAsync(Guid bookingId, CancellationToken ct = default)
        {
            OpenCalled = true;
            return Task.FromResult(Result.Success());
        }

        public Task<Result> ResolveAsync(Guid bookingId, string decision,
            DateTimeOffset resolvedAt, CancellationToken ct = default) =>
            Task.FromResult(Result.Success());
    }

    private sealed class SupportRepositoryStub : ISupportRepository
    {
        public List<Dispute> Disputes { get; } = [];
        public List<Review> Reviews { get; } = [];

        public Task<bool> DisputeExistsAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(Disputes.Any(x => x.BookingId == bookingId));
        public Task<Dispute?> GetDisputeAsync(Guid id, CancellationToken ct = default) =>
            Task.FromResult(Disputes.SingleOrDefault(x => x.Id == id));
        public void AddDispute(Dispute dispute) => Disputes.Add(dispute);
        public Task<Notification?> GetNotificationAsync(Guid id, Guid userId,
            CancellationToken ct = default) => Task.FromResult<Notification?>(null);
        public Task<List<Notification>> GetUnreadNotificationsAsync(Guid userId,
            CancellationToken ct = default) => Task.FromResult(new List<Notification>());
        public void AddNotification(Notification notification) { }
        public Task<bool> ReviewExistsAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(Reviews.Any(x => x.BookingId == bookingId));
        public Task<bool> TryAddReviewAsync(Review review, CancellationToken ct = default)
        {
            if (Reviews.Any(x => x.BookingId == review.BookingId)) return Task.FromResult(false);
            Reviews.Add(review);
            return Task.FromResult(true);
        }
        public Task<SupportTicket?> GetSupportTicketAsync(Guid id,
            CancellationToken ct = default) => Task.FromResult<SupportTicket?>(null);
        public void AddSupportTicket(SupportTicket ticket) { }
        public Task SaveChangesAsync(CancellationToken ct = default) => Task.CompletedTask;
    }
}
