using System.Text.Json;
using CareSitter.ApiHost.Controllers;
using CareSitter.ApiHost.Application.Admin;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.IntegrationTests;

public sealed class AdminDashboardTests
{
    [Fact]
    public async Task Critical_and_high_priority_tickets_survive_the_combined_queue_limit()
    {
        var now = DateTimeOffset.UtcNow;
        var olderPayments = Enumerable.Range(0, 12).Select(index => Item("PAYMENT", now.AddDays(-2).AddMinutes(index))).ToArray();
        var critical = Item("SUPPORT", now) with { Priority = "CRITICAL" };
        var high = Item("SUPPORT", now.AddMinutes(-1)) with { Priority = "HIGH" };
        var readers = new Readers(olderPayments, [high, critical]);
        var services = new ServiceCollection();
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<GetAdminDashboardQuery>());
        services.AddSingleton<IAdminBookingReader>(readers);
        services.AddSingleton<IAdminPeopleReader>(readers);
        services.AddSingleton<IAdminPaymentsReader>(readers);
        services.AddSingleton<IAdminSupportReader>(readers);
        services.AddSingleton<IAdminIdentityReader>(readers);
        using var provider = services.BuildServiceProvider();
        var controller = new AdminDashboardController(provider.GetRequiredService<IMediator>());

        var result = Assert.IsType<OkObjectResult>(await controller.Get(CancellationToken.None));
        var payload = JsonSerializer.SerializeToElement(result.Value);
        var items = payload.GetProperty("workItems").EnumerateArray().ToArray();

        Assert.Equal(12, items.Length);
        Assert.Equal(critical.Id, items[0].GetProperty("Id").GetGuid());
        Assert.Equal(high.Id, items[1].GetProperty("Id").GetGuid());
        Assert.Equal(olderPayments[0].Id, items[2].GetProperty("Id").GetGuid());
    }

    private static AdminQueueItem Item(string type, DateTimeOffset at) => new(type, Guid.NewGuid(), "Review", "", "NEW", at);

    private sealed class Readers(AdminQueueItem[] payments, AdminQueueItem[] support) :
        IAdminBookingReader, IAdminPeopleReader, IAdminPaymentsReader, IAdminSupportReader, IAdminIdentityReader
    {
        Task<AdminBookingSnapshot> IAdminBookingReader.GetDashboardSnapshotAsync(DateTimeOffset from, DateTimeOffset until, CancellationToken ct) =>
            Task.FromResult(new AdminBookingSnapshot(0, new Dictionary<string, int>()));
        public IReadOnlyList<AdminStatusDescriptor> GetStatusDescriptors() => [];
        Task<AdminPeopleSnapshot> IAdminPeopleReader.GetDashboardSnapshotAsync(CancellationToken ct) => Task.FromResult(new AdminPeopleSnapshot(0, []));
        Task<AdminPaymentsSnapshot> IAdminPaymentsReader.GetDashboardSnapshotAsync(CancellationToken ct) => Task.FromResult(new AdminPaymentsSnapshot(0, payments.Length, payments));
        Task<AdminSupportSnapshot> IAdminSupportReader.GetDashboardSnapshotAsync(CancellationToken ct) => Task.FromResult(new AdminSupportSnapshot(support.Length, 0, support));
        public IReadOnlyDictionary<string, string[]> GetTicketTransitions() => new Dictionary<string, string[]>();
        public Task<int> CountActiveUsersAsync(CancellationToken ct) => Task.FromResult(0);
        public Task<AdminUserProfile?> FindUserAsync(Guid userId, CancellationToken ct) => Task.FromResult<AdminUserProfile?>(null);
    }
}
