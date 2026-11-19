using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking;
using CareSitter.Modules.Catalog;
using CareSitter.Modules.Catalog.Application;
using CareSitter.Modules.Identity;
using CareSitter.Modules.Payments;
using CareSitter.Modules.Support;
using CareSitter.Modules.Support.Application;
using CareSitter.Modules.Support.Application.Commands.CancelDispute;
using CareSitter.Modules.Support.Application.Commands.CreateDispute;
using CareSitter.Modules.Support.Application.Commands.ResolveDispute;
using CareSitter.Modules.Support.Application.Ports;
using CareSitter.Modules.Support.Domain;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.SharedKernel.Results;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingTransactionIntegrityTests
{
    [PostgresFact]
    public async Task DisputeWorkflow_RollbackAndReplay_UsesThePreviewedAllocation()
    {
        var seed = await GetSeedAsync();
        var booking = await CreateFinancialBookingAsync(seed, "COMPLETED", DateTimeOffset.UtcNow);
        await ResetWalletsAsync(seed);
        await InsertEscrowLockAsync(booking, 100_000);
        await InsertSucceededPayOSIntentAsync(booking, seed.CustomerId, 100_000);
        var audit = new WorkflowAudit();
        await using var provider = BuildWorkflowServices(seed, audit);
        var open = new CreateDisputeCommand(booking, "SERVICE", "Kiểm tra");
        var dispute = (await SendAsync(provider, open)).Value;
        Assert.Equal(dispute.Id, (await SendAsync(provider, open)).Value.Id);
        var invalid = new ResolveDisputeCommand(dispute.Id, "PARTIAL_REFUND", 100_000, 0);
        Assert.True((await SendAsync(provider, invalid)).IsFailure);
        var preview = (await SendAsync(provider, new PreviewDisputeQuery(dispute.Id, "PARTIAL_REFUND", 40_000, 0))).Value;
        var decide = invalid with { RefundAmount = 40_000, ExpectedQuote = preview };
        var stale = decide with { ExpectedQuote = preview with { Earning = preview.Earning + 1 } };
        Assert.Equal("dispute.quote_changed", (await SendAsync(provider, stale)).Error.Code);
        audit.FailResolution = true;
        await Assert.ThrowsAsync<InjectedAuditFailure>(() => SendAsync(provider, decide));
        Assert.Equal("DISPUTED", await ReadBookingStatusAsync(booking));
        Assert.Equal(0, (await ReadFinancialStateAsync(booking, seed)).PostedResolutionEntries);
        Assert.Equal(0L, await RefundRequestsAsync(booking));
        audit.FailResolution = false;
        var resolved = await SendAsync(provider, decide);
        Assert.True(resolved.IsSuccess, resolved.Error.Message);
        Assert.Equal("RESOLVED", resolved.Value.Status);
        Assert.Equal(resolved.Value.Id, (await SendAsync(provider, decide)).Value.Id);
        Assert.Equal(1L, await RefundRequestsAsync(booking));
        Assert.Equal(preview.Earning, (await ReadFinancialStateAsync(booking, seed)).CaregiverEarningAmount);
    }

    [PostgresFact]
    public async Task DisputeWorkflow_WithdrawalRestoresThePriorBookingAndCanBeRetried()
    {
        var seed = await GetSeedAsync();
        var booking = await CreateFinancialBookingAsync(seed, "CHECKOUT_PENDING_REVIEW");
        await using var provider = BuildWorkflowServices(seed, new WorkflowAudit());
        var opened = await SendAsync(provider, new CreateDisputeCommand(booking, "SERVICE", null));
        Assert.True(opened.IsSuccess, opened.Error.Message);
        var cancel = new CancelDisputeCommand(opened.Value.Id);
        Assert.Equal("CANCELLED", (await SendAsync(provider, cancel)).Value.Status);
        Assert.Equal("CHECKOUT_PENDING_REVIEW", await ReadBookingStatusAsync(booking));
        Assert.Equal("CANCELLED", (await SendAsync(provider, cancel)).Value.Status);
    }

    [PostgresFact]
    public async Task CatalogWorkflow_InvalidChecklistRollsBackAndRetryCreatesOneCompleteService()
    {
        var seed = await GetSeedAsync();
        await using var provider = BuildWorkflowServices(seed, new WorkflowAudit());
        var validItem = new ServiceChecklistItem("Chăm sóc", null, true, false, 1);
        var service = new CreateServiceCommand("TEST_SETUP", "Test setup", null, null, 60, true);
        var price = new CreatePricingRuleCommand(Guid.Empty, "Giá thường", 100_000, 1m, 1m, 15m, 48,
            DateTimeOffset.UtcNow.AddMinutes(-1), null, true);
        var setup = new CreateServiceBundleCommand(Guid.NewGuid(), service, price, [validItem, validItem with { Name = "x" }]);
        var failed = await SendAsync(provider, setup);
        Assert.Equal("checklist.name", failed.Error.Code);
        var valid = setup with { Checklist = [validItem] };
        var created = await SendAsync(provider, valid);
        Assert.True(created.IsSuccess, created.Error.Message);
        Assert.Equal(created.Value.Id, (await SendAsync(provider, valid)).Value.Id);
        Assert.Equal("catalog.setup_changed", (await SendAsync(provider, setup)).Error.Code);
        var unpriced = (await SendAsync(provider, service with { Code = "TEST_UNPRICED" })).Value;
        using var scope = provider.CreateScope();
        var visible = await scope.ServiceProvider.GetRequiredService<ISender>().Send(new ListActiveServicesQuery());
        Assert.Contains(visible, x => x.Id == created.Value.Id);
        Assert.DoesNotContain(visible, x => x.Id == unpriced.Id);
    }

    [PostgresFact]
    public async Task PushWorkflow_SecondClaimOmitsDeliveredDeviceAndRejectsStaleCheckpoint()
    {
        var seed = await GetSeedAsync();
        await using var provider = BuildWorkflowServices(seed, new WorkflowAudit());
        using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<SupportDbContext>();
        var store = scope.ServiceProvider.GetRequiredService<INotificationDeliveryStore>();
        var item = Notification.Create(seed.CustomerId, "SYSTEM", "Test push").Value;
        var evt = Guid.NewGuid();
        db.Notifications.Add(item);
        db.Add(new NotificationDelivery { EventId = evt, Channel = "push", NotificationId = item.Id });
        await db.SaveChangesAsync();
        var first = await store.ClaimAsync(evt, item.Id, seed.CustomerId, "push", default);
        Assert.Equal(new[] { "device-A", "device-B" }, first.PushTokens);
        var keyA = PushTargetKey.FromToken("device-A");
        Assert.True(await store.CheckpointAsync(evt, first.ClaimToken!.Value, [keyA], default));
        Assert.True(await store.CompleteAsync(evt, "push", first.ClaimToken.Value, false, "transient", default));
        var retry = await store.ClaimAsync(evt, item.Id, seed.CustomerId, "push", default);
        Assert.Equal(new[] { "device-B" }, retry.PushTokens);
        Assert.False(await store.CheckpointAsync(evt, first.ClaimToken.Value, [PushTargetKey.FromToken("device-B")], default));
        Assert.True(await store.CompleteAsync(evt, "push", retry.ClaimToken!.Value, true, null, default));
        Assert.Equal("Sent", (await store.ClaimAsync(evt, item.Id, seed.CustomerId, "push", default)).Status);
    }

    private async Task<string> ReadBookingStatusAsync(Guid booking)
    {
        await using var db = await _database.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT upper(status::text) FROM booking.bookings WHERE id = @id", db);
        cmd.Parameters.AddWithValue("id", booking);
        return (string)(await cmd.ExecuteScalarAsync())!;
    }

    private async Task<long> RefundRequestsAsync(Guid booking)
    {
        await using var db = await _database.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("SELECT count(*) FROM payments.refund_requests WHERE booking_id = @id", db);
        cmd.Parameters.AddWithValue("id", booking);
        return (long)(await cmd.ExecuteScalarAsync())!;
    }

    private ServiceProvider BuildWorkflowServices(SeedRecord seed, WorkflowAudit audit)
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:CareSitter"] = _database.ConnectionString
        }).Build();
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton<IClock, CareSitter.Infrastructure.Time.SystemClock>();
        services.AddHttpContextAccessor();
        services.AddSingleton<IConfiguration>(config);
        new IdentityModule().RegisterServices(services, config);
        new CatalogModule().RegisterServices(services, config);
        new BookingModule().RegisterServices(services, config);
        new PaymentsModule().RegisterServices(services, config);
        new SupportModule().RegisterServices(services, config);
        services.AddSingleton<ICurrentUser>(new WorkflowActor(seed.CustomerId));
        services.AddSingleton<IPeopleLookupService>(new PeopleLookupStub(seed.CaregiverProfileId, seed.CaregiverUserId));
        services.AddSingleton<IAuditLogger>(audit);
        services.AddSingleton<INotificationRecipientReader>(new TwoDevices());
        return services.BuildServiceProvider();
    }

    private static async Task<Result<T>> SendAsync<T>(ServiceProvider provider, IRequest<Result<T>> request)
    {
        await using var scope = provider.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<ISender>().Send(request);
    }

    private sealed class WorkflowActor(Guid id) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => ["CUSTOMER", "ADMIN"];
        public bool IsInRole(string role) => Roles.Contains(role);
    }

    private sealed class InjectedAuditFailure : Exception { }

    private sealed class WorkflowAudit : IAuditLogger
    {
        public bool FailResolution { get; set; }
        public Task WriteAsync(string action, string entityType, Guid entityId, object? before, object? after,
            CancellationToken ct = default) => FailResolution && action == "ADMIN_DISPUTE_RESOLVED"
                ? throw new InjectedAuditFailure() : Task.CompletedTask;
    }

    private sealed class TwoDevices : INotificationRecipientReader
    {
        public Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct) =>
            Task.FromResult(new NotificationRecipient(null, ["device-A", "device-B"]));
    }
}
