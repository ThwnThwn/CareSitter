using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Domain;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class CustomerRefundQueryTests
{
    [Fact]
    public async Task Customer_only_sees_their_own_refunds()
    {
        var customerId = Guid.NewGuid();
        await using var db = CreateDbContext();
        db.RefundRequests.Add(CreateRefund(customerId, 40_000));
        db.RefundRequests.Add(CreateRefund(Guid.NewGuid(), 90_000));
        await db.SaveChangesAsync();
        var handler = new ListMyRefundsQueryHandler(
            new RefundStore(db), new CurrentUserStub(customerId, "CUSTOMER"));

        var result = await handler.Handle(
            new ListMyRefundsQuery(1, 20), CancellationToken.None);

        Assert.True(result.IsSuccess);
        var refund = Assert.Single(result.Value.Items);
        Assert.Equal(40_000, refund.Amount);
        Assert.Equal("MANUAL_REQUIRED", refund.Status);
    }

    private static RefundRequest CreateRefund(Guid customerId, long amount)
    {
        var intent = PaymentIntent.Create(
            Guid.NewGuid(), customerId, "PAYOS", 100_000,
            Guid.NewGuid().ToString("N")).Value;
        Assert.True(intent.SetProviderOrderRef(
            Random.Shared.NextInt64(1, 9_007_199_254_740_991).ToString()).IsSuccess);
        Assert.True(intent.MarkPending().IsSuccess);
        Assert.True(intent.MarkSucceeded(
            Guid.NewGuid().ToString("N"), finalizedSource: "TEST").IsSuccess);
        return RefundRequest.Create(
            intent, amount, "DISPUTE_PARTIAL_REFUND", DateTimeOffset.UtcNow,
            canProcessAutomatically: false).Value;
    }

    private static PaymentsDbContext CreateDbContext() => new(
        new DbContextOptionsBuilder<PaymentsDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options);

    private sealed class CurrentUserStub(Guid? userId, params string[] roles)
        : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) =>
            roles.Contains(role, StringComparer.OrdinalIgnoreCase);
    }
}
