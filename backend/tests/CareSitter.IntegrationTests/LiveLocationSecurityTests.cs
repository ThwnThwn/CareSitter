using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.Commands.PostBookingGps;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.SignalR;

namespace CareSitter.IntegrationTests;

public sealed class LiveLocationSecurityTests
{
    [Theory]
    [InlineData(double.NaN, 106)]
    [InlineData(double.PositiveInfinity, 106)]
    [InlineData(double.NegativeInfinity, 106)]
    [InlineData(91, 106)]
    [InlineData(-91, 106)]
    [InlineData(10, 181)]
    [InlineData(10, -181)]
    public void InvalidCoordinatesAreRejected(double latitude, double longitude)
    {
        var sample = new PostBookingGpsCommand(Guid.NewGuid(), Guid.NewGuid(), latitude, longitude, DateTimeOffset.UtcNow);
        Assert.False(new PostBookingGpsCommandValidator().Validate(sample).IsValid);
    }

    [Fact]
    public void NonFiniteOptionalValuesAndEmptySessionsAreRejected()
    {
        var sample = new PostBookingGpsCommand(Guid.NewGuid(), Guid.NewGuid(), 10, 106, DateTimeOffset.UtcNow);
        var validator = new PostBookingGpsCommandValidator();
        Assert.True(validator.Validate(sample).IsValid);
        foreach (var invalid in new[] {
            sample with { AccuracyMeters = double.NaN }, sample with { AccuracyMeters = -1 },
            sample with { Speed = double.PositiveInfinity }, sample with { Heading = 360 },
            sample with { SessionId = Guid.Empty }, sample with { CapturedAt = default } })
            Assert.False(validator.Validate(invalid).IsValid);
    }

    [Fact]
    public async Task GpsIsBroadcastOnlyToOwningCustomer_NotBookingMembersOrOtherCustomers()
    {
        var customer = Guid.NewGuid();
        var hub = new RecordingHub();
        var payload = new GpsTrackResponse(Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(),
            10, 106, 5, null, null, DateTimeOffset.UtcNow, 12);
        await new BookingTrackingNotifier(hub).GpsUpdatedAsync(customer, payload);
        Assert.Equal(new[] { CareTrackingHub.CustomerGroup(customer) }, hub.Recorder.Groups);
        Assert.Equal("GpsUpdated", hub.Recorder.Method);
        Assert.Same(payload, Assert.Single(hub.Recorder.Arguments!));
    }

    private sealed class RecordingHub : IHubContext<CareTrackingHub>
    {
        public RecordingClients Recorder { get; } = new();
        public IHubClients Clients => Recorder;
        public IGroupManager Groups => throw new NotSupportedException();
    }
    private sealed class RecordingClients : IHubClients, IClientProxy
    {
        public List<string> Groups { get; } = [];
        public string? Method { get; private set; }
        public object?[]? Arguments { get; private set; }
        public IClientProxy Group(string groupName) { Groups.Add(groupName); return this; }
        public Task SendCoreAsync(string method, object?[] args, CancellationToken cancellationToken = default)
        { Method = method; Arguments = args; return Task.CompletedTask; }
        public IClientProxy All => throw new InvalidOperationException("GPS must never broadcast to everyone.");
        public IClientProxy AllExcept(IReadOnlyList<string> excludedConnectionIds) => throw new NotSupportedException();
        public IClientProxy Client(string connectionId) => throw new NotSupportedException();
        public IClientProxy Clients(IReadOnlyList<string> connectionIds) => throw new NotSupportedException();
        public IClientProxy GroupExcept(string groupName, IReadOnlyList<string> excludedConnectionIds) => throw new NotSupportedException();
        IClientProxy IHubClients<IClientProxy>.Groups(IReadOnlyList<string> groupNames) => throw new NotSupportedException();
        public IClientProxy User(string userId) => throw new NotSupportedException();
        public IClientProxy Users(IReadOnlyList<string> userIds) => throw new NotSupportedException();
    }
}
