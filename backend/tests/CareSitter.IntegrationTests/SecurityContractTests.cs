using System.IdentityModel.Tokens.Jwt;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.ApiHost.Controllers;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Security;
using CareSitter.Modules.Booking.Application.Commands.CompleteBooking;
using CareSitter.Modules.Booking.Application.Commands.StartBookingEnRoute;
using CareSitter.Modules.Booking.Controllers;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Catalog.Controllers;
using CareSitter.Modules.Catalog.Domain;
using CareSitter.Modules.Identity.Application.Login;
using CareSitter.Modules.Identity.Application.GoogleLogin;
using CareSitter.Modules.Identity.Domain.Policies;
using CareSitter.Modules.Identity.Infrastructure;
using CareSitter.Modules.Identity.Controllers;
using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Payments.Controllers;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.People.Controllers;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.Support.Controllers;
using CareSitter.Modules.Support.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed class SecurityContractTests
{
    [Fact]
    public void Access_token_is_bound_to_a_durable_session()
    {
        var sessionId = Guid.NewGuid();
        var settings = Options.Create(new JwtSettings
        {
            Issuer = "CareSitter.Tests",
            Audience = "CareSitter.Tests.Client",
            SecretKey = "test-only-secret-key-with-more-than-32-characters",
            ExpiryMinutes = 15
        });
        var service = new JwtTokenService(settings);

        var raw = service.GenerateAccessToken(
            Guid.NewGuid(), ["ADMIN"], "Security Admin", sessionId);
        var token = new JwtSecurityTokenHandler().ReadJwtToken(raw);

        Assert.Equal(sessionId.ToString(), token.Claims.Single(x => x.Type == "sid").Value);
        Assert.NotEmpty(token.Claims.Single(x => x.Type == JwtRegisteredClaimNames.Jti).Value);
    }

    [Fact]
    public void Admin_login_requires_the_admin_role()
    {
        var admin = User.Create(Guid.NewGuid(), "admin@example.test").Value;
        admin.SetRoles(["ADMIN"]);
        var customer = User.Create(Guid.NewGuid(), "customer@example.test").Value;
        customer.SetRoles(["CUSTOMER"]);

        Assert.True(AuthRoleRequirement.Validate(admin, "ADMIN").IsSuccess);
        Assert.True(AuthRoleRequirement.Validate(customer, "ADMIN").IsFailure);
        Assert.True(AuthRoleRequirement.Normalize("ROOT").IsFailure);
    }

    [Fact]
    public void Google_login_role_is_server_owned_and_admin_self_registration_is_rejected()
    {
        var request = JsonSerializer.Deserialize<GoogleLoginRequest>(
            "{\"idToken\":\"token\",\"roles\":[\"ADMIN\"]}",
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

        Assert.NotNull(request);
        Assert.Equal("token", request!.IdToken);
        Assert.Single(typeof(GoogleLoginRequest).GetProperties());
        Assert.True(GoogleLoginRolePolicy.Validate("CUSTOMER").IsSuccess);
        Assert.True(GoogleLoginRolePolicy.Validate("CAREGIVER").IsSuccess);
        Assert.True(GoogleLoginRolePolicy.Validate("ADMIN").IsFailure);
        Assert.True(GoogleLoginRolePolicy.Validate(null).IsFailure);

        Assert.Equal("google/customer", GetHttpPostTemplate(
            typeof(AuthController), nameof(AuthController.GoogleCustomer)));
        Assert.Equal("google/caregiver", GetHttpPostTemplate(
            typeof(AuthController), nameof(AuthController.GoogleCaregiver)));
        Assert.Null(typeof(AuthController).GetMethod("GoogleCallback"));
    }

    [Fact]
    public async Task Identifier_is_blocked_after_five_failed_logins_and_can_be_reset()
    {
        var cache = new TestDistributedCache();
        var limiter = new AuthenticationAttemptLimiter(cache);
        const string identifier = "person@example.test";

        for (var attempt = 1; attempt <= 5; attempt++)
            await limiter.RecordFailureAsync("password-login", identifier, 5,
                TimeSpan.FromMinutes(15), TimeSpan.FromMinutes(15), CancellationToken.None);

        Assert.True(await limiter.IsBlockedAsync(
            "password-login", identifier, CancellationToken.None));
        await limiter.ResetAsync("password-login", identifier, CancellationToken.None);
        Assert.False(await limiter.IsBlockedAsync(
            "password-login", identifier, CancellationToken.None));
    }

    [Fact]
    public async Task Otp_send_window_rejects_the_sixth_request()
    {
        var cache = new TestDistributedCache();
        var limiter = new AuthenticationAttemptLimiter(cache);

        for (var request = 1; request <= 5; request++)
            Assert.True(await limiter.TryConsumeAsync("otp-send", "person@example.test", 5,
                TimeSpan.FromHours(1), CancellationToken.None));

        Assert.False(await limiter.TryConsumeAsync("otp-send", "person@example.test", 5,
            TimeSpan.FromHours(1), CancellationToken.None));
    }

    [Theory]
    [MemberData(nameof(AdminControllers))]
    public void Admin_controller_requires_admin_role(Type controllerType)
    {
        var authorize = Assert.Single(controllerType
            .GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
            .Cast<AuthorizeAttribute>());

        Assert.Equal("ADMIN", authorize.Roles);
    }

    public static TheoryData<Type> AdminControllers => new()
    {
        typeof(AdminUsersController),
        typeof(AdminCatalogController),
        typeof(AdminChecklistTemplatesController),
        typeof(PaymentReconciliationController),
        typeof(AdminDashboardController),
        typeof(AdminMetadataController)
    };

    [Theory]
    [MemberData(nameof(RoleBoundActions))]
    public void Sensitive_action_declares_its_role_boundary(
        Type controllerType,
        string methodName,
        string expectedRoles)
    {
        var method = controllerType.GetMethod(methodName);
        Assert.NotNull(method);
        var authorize = Assert.Single(method!
            .GetCustomAttributes(typeof(AuthorizeAttribute), inherit: true)
            .Cast<AuthorizeAttribute>());
        Assert.Equal(expectedRoles, authorize.Roles);
    }

    public static TheoryData<Type, string, string> RoleBoundActions => new()
    {
        { typeof(CaregiverKycController), nameof(CaregiverKycController.ApproveKyc), "ADMIN" },
        { typeof(PayoutsController), nameof(PayoutsController.Approve), "ADMIN" },
        { typeof(DisputesController), nameof(DisputesController.Resolve), "ADMIN" },
        { typeof(SupportTicketsController), nameof(SupportTicketsController.Assign), "ADMIN" },
        { typeof(BookingsController), nameof(BookingsController.Accept), "CAREGIVER" },
        { typeof(BookingsController), nameof(BookingsController.Complete), "CUSTOMER,ADMIN" },
        { typeof(CareTasksController), nameof(CareTasksController.CompleteTask), "CAREGIVER" },
        { typeof(BookingTrackingController), nameof(BookingTrackingController.PostGps), "CAREGIVER" }
    };

    [Fact]
    public void Kyc_review_only_allows_pending_profiles()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        Assert.True(profile.SubmitKyc("encrypted", "hash",
            "https://cdn.test/front.jpg", "https://cdn.test/back.jpg", "[]").IsSuccess);

        Assert.True(profile.ApproveKyc().IsSuccess);
        Assert.Equal("APPROVED", profile.KycStatus);
        Assert.True(profile.RejectKyc().IsFailure);
    }

    [Fact]
    public void Payout_review_records_admin_and_rejects_a_second_transition()
    {
        var adminId = Guid.NewGuid();
        var payout = PayoutRequest.Create(Guid.NewGuid(), Guid.NewGuid(), "phase10-key",
            200_000, "VCB", "970436", "NGUYEN VAN A", "encrypted").Value;

        Assert.True(payout.Approve(adminId).IsSuccess);
        Assert.Equal(adminId, payout.ReviewedByAdminId);
        Assert.True(payout.Reject(Guid.NewGuid(), "late retry").IsFailure);
    }

    [Fact]
    public void Dispute_resolution_records_admin_and_financial_decision_once()
    {
        var adminId = Guid.NewGuid();
        var dispute = Dispute.Create(Guid.NewGuid(), Guid.NewGuid()).Value;

        Assert.True(dispute.Resolve(adminId, "PARTIAL_REFUND", 50_000, 10_000).IsSuccess);
        Assert.Equal(adminId, dispute.DecidedByAdminId);
        Assert.Equal(50_000, dispute.RefundAmount);
        Assert.Equal(10_000, dispute.CaregiverPenaltyAmount);
        Assert.True(dispute.Resolve(adminId, "CUSTOMER_WINS").IsFailure);
    }

    [Fact]
    public void User_and_service_admin_mutations_validate_their_boundaries()
    {
        var user = User.Create(Guid.NewGuid(), "user@example.test").Value;
        Assert.True(user.SetStatus("LOCKED").IsSuccess);
        Assert.True(user.SetStatus("UNKNOWN").IsFailure);

        var service = ServiceType.Create("elder-care", "Chăm sóc người cao tuổi").Value;
        Assert.True(service.Update("elder-care", "Chăm sóc", null, 14).IsFailure);
        Assert.True(service.Update("elder-care", "Chăm sóc", null, 60).IsSuccess);
    }

    [Fact]
    public void Audit_entry_keeps_actor_before_after_and_context()
    {
        var actorId = Guid.NewGuid();
        var entityId = Guid.NewGuid();
        var result = AuditLog.Create(
            "ADMIN_USER_STATUS_UPDATED", "User", actorId, entityId,
            afterData: "{\"status\":\"LOCKED\"}",
            ipAddress: "127.0.0.1",
            userAgent: "security-test",
            beforeData: "{\"status\":\"ACTIVE\"}",
            actorRole: "ADMIN");

        Assert.True(result.IsSuccess);
        Assert.Equal(actorId, result.Value.ActorUserId);
        Assert.Equal("ADMIN", result.Value.ActorRole);
        Assert.Contains("ACTIVE", result.Value.BeforeData);
        Assert.Contains("LOCKED", result.Value.AfterData);
    }

    [Fact]
    public async Task Booking_completion_enforces_anonymous_role_and_customer_ownership_boundaries()
    {
        var customerId = Guid.NewGuid();
        var caregiverUserId = Guid.NewGuid();
        var booking = CreateAssignedBooking(customerId, Guid.NewGuid());
        var repository = new BookingRepositoryStub(booking);

        var anonymousResult = await CreateCompleteHandler(
            repository, new CurrentUserStub(null)).Handle(
            new CompleteBookingCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.unauthenticated", anonymousResult.Error.Code);

        var otherCustomerResult = await CreateCompleteHandler(
            repository, new CurrentUserStub(Guid.NewGuid(), "CUSTOMER")).Handle(
            new CompleteBookingCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.forbidden", otherCustomerResult.Error.Code);

        var caregiverResult = await CreateCompleteHandler(
            repository, new CurrentUserStub(caregiverUserId, "CAREGIVER")).Handle(
            new CompleteBookingCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.forbidden", caregiverResult.Error.Code);

        var ownerResult = await CreateCompleteHandler(
            repository, new CurrentUserStub(customerId, "CUSTOMER")).Handle(
            new CompleteBookingCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.complete.invalid_state", ownerResult.Error.Code);

        var adminResult = await CreateCompleteHandler(
            repository, new CurrentUserStub(Guid.NewGuid(), "ADMIN")).Handle(
            new CompleteBookingCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.complete.invalid_state", adminResult.Error.Code);
    }

    [Fact]
    public async Task Caregiver_action_rejects_anonymous_customer_and_unassigned_caregiver()
    {
        var customerId = Guid.NewGuid();
        var assignedCaregiverUserId = Guid.NewGuid();
        var otherCaregiverUserId = Guid.NewGuid();
        var caregiverProfileId = Guid.NewGuid();
        var booking = CreateAssignedBooking(customerId, caregiverProfileId);
        Assert.True(booking.StartEnRoute().IsSuccess);

        var repository = new BookingRepositoryStub(booking);
        var people = new PeopleLookupStub(caregiverProfileId, assignedCaregiverUserId);

        var anonymousResult = await CreateStartEnRouteHandler(
            repository, new CurrentUserStub(null), people).Handle(
            new StartBookingEnRouteCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.unauthenticated", anonymousResult.Error.Code);

        var customerResult = await CreateStartEnRouteHandler(
            repository, new CurrentUserStub(customerId, "CUSTOMER"), people).Handle(
            new StartBookingEnRouteCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.forbidden", customerResult.Error.Code);

        var otherCaregiverResult = await CreateStartEnRouteHandler(
            repository, new CurrentUserStub(otherCaregiverUserId, "CAREGIVER"), people).Handle(
            new StartBookingEnRouteCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.forbidden", otherCaregiverResult.Error.Code);

        var assignedCaregiverResult = await CreateStartEnRouteHandler(
            repository, new CurrentUserStub(assignedCaregiverUserId, "CAREGIVER"), people).Handle(
            new StartBookingEnRouteCommand(booking.Id), CancellationToken.None);
        Assert.Equal("booking.transition", assignedCaregiverResult.Error.Code);
    }

    private static CompleteBookingCommandHandler CreateCompleteHandler(
        IBookingRepository repository, ICurrentUser currentUser) =>
        new(repository, currentUser, null!, null!, null!, null!, null!, null!);

    private static string? GetHttpPostTemplate(Type controllerType, string methodName) =>
        controllerType.GetMethod(methodName)?
            .GetCustomAttributes(typeof(HttpPostAttribute), inherit: true)
            .Cast<HttpPostAttribute>()
            .Single()
            .Template;

    private static StartBookingEnRouteCommandHandler CreateStartEnRouteHandler(
        IBookingRepository repository, ICurrentUser currentUser, IPeopleLookupService people) =>
        new(repository, currentUser, people, null!, null!, null!, null!);

    private static Booking CreateAssignedBooking(Guid customerId, Guid caregiverProfileId)
    {
        var booking = Booking.Create(
            customerId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            DateTimeOffset.UtcNow.AddHours(1),
            DateTimeOffset.UtcNow.AddHours(3)).Value;
        Assert.True(booking.TransitionTo(BookingStatus.PendingPayment).IsSuccess);
        Assert.True(booking.ConfirmPayment().IsSuccess);
        Assert.True(booking.AssignCaregiver(caregiverProfileId).IsSuccess);
        return booking;
    }

    private sealed class CurrentUserStub(Guid? userId, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) => roles.Contains(role, StringComparer.OrdinalIgnoreCase);
    }

    private sealed class PeopleLookupStub(Guid caregiverProfileId, Guid caregiverUserId)
        : IPeopleLookupService
    {
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start,
            DateTimeOffset end, CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId,
            CancellationToken ct = default) => Task.FromResult(
                caregiverId == caregiverProfileId && userId == caregiverUserId);
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(
                userId == caregiverUserId ? caregiverProfileId : null);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<Guid?>(
                caregiverId == caregiverProfileId ? caregiverUserId : null);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId,
            CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
    }

    private sealed class BookingRepositoryStub(Booking booking) : IBookingRepository
    {
        public Task<Booking?> GetByIdAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult<Booking?>(bookingId == booking.Id ? booking : null);
        public Task<Booking?> GetByIdReadOnlyAsync(Guid bookingId, CancellationToken ct) =>
            GetByIdAsync(bookingId, ct);
        public Task<Booking?> GetForCustomerAsync(Guid bookingId, Guid customerId,
            CancellationToken ct) => Task.FromResult<Booking?>(
                bookingId == booking.Id && customerId == booking.CustomerId ? booking : null);
        public Task<bool> HasBeneficiaryScheduleConflictAsync(Guid bookingId, Guid beneficiaryId,
            DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) =>
            Task.FromResult(false);
        public Task<bool> HasCaregiverScheduleConflictAsync(Guid bookingId, Guid caregiverId,
            DateTimeOffset scheduledStart, DateTimeOffset scheduledEnd, CancellationToken ct) =>
            Task.FromResult(false);
        public Task<List<CareTask>> GetPendingCareTasksAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult(new List<CareTask>());
        public Task<bool> HasPendingCareTasksAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult(false);
        public Task<bool> HasRequiredSkippedCareTasksAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult(false);
        public Task<List<CaregiverSlotHold>> GetActiveSlotHoldsAsync(Guid bookingId,
            CancellationToken ct) => Task.FromResult(new List<CaregiverSlotHold>());
        public Task<CaregiverSlotHold?> GetActiveSlotHoldAsync(Guid bookingId,
            CancellationToken ct) => Task.FromResult<CaregiverSlotHold?>(null);
        public Task<BookingAssignment?> GetActiveAssignmentReadOnlyAsync(Guid bookingId,
            Guid caregiverId, DateTimeOffset now, CancellationToken ct) =>
            Task.FromResult<BookingAssignment?>(null);
        public Task<bool> HasAnyAssignmentAsync(Guid bookingId, CancellationToken ct) =>
            Task.FromResult(false);
        public Task<BookingAssignment?> GetActiveAssignmentAsync(Guid bookingId, Guid caregiverId,
            CancellationToken ct) => Task.FromResult<BookingAssignment?>(null);
        public Task<List<BookingAssignment>> GetOtherOfferedAssignmentsAsync(Guid bookingId,
            Guid caregiverId, CancellationToken ct) =>
            Task.FromResult(new List<BookingAssignment>());
        public Task<BookingAssignment?> GetAssignmentAsync(Guid bookingId, Guid caregiverId,
            CancellationToken ct) => Task.FromResult<BookingAssignment?>(null);
        public Task<bool> HasActiveOfferAsync(Guid bookingId, DateTimeOffset now,
            CancellationToken ct) => Task.FromResult(false);
        public void Add(Booking value) { }
        public void AddSlotHold(CaregiverSlotHold slotHold) { }
        public void AddAssignment(BookingAssignment assignment) { }
        public void AddTimelineEvent(CareTimelineEvent timelineEvent) { }
        public Task SaveChangesAsync(CancellationToken ct) => Task.CompletedTask;
        public Task<bool> TrySaveSlotHoldChangesAsync(CancellationToken ct) =>
            Task.FromResult(true);
    }

    private sealed class TestDistributedCache : IDistributedCache
    {
        private readonly Dictionary<string, byte[]> _values = new(StringComparer.Ordinal);

        public byte[]? Get(string key) => _values.GetValueOrDefault(key);
        public Task<byte[]?> GetAsync(string key, CancellationToken token = default) =>
            Task.FromResult(Get(key));
        public void Set(string key, byte[] value, DistributedCacheEntryOptions options) =>
            _values[key] = value;
        public Task SetAsync(string key, byte[] value, DistributedCacheEntryOptions options,
            CancellationToken token = default)
        {
            Set(key, value, options);
            return Task.CompletedTask;
        }
        public void Refresh(string key) { }
        public Task RefreshAsync(string key, CancellationToken token = default) => Task.CompletedTask;
        public void Remove(string key) => _values.Remove(key);
        public Task RemoveAsync(string key, CancellationToken token = default)
        {
            Remove(key);
            return Task.CompletedTask;
        }
    }
}
