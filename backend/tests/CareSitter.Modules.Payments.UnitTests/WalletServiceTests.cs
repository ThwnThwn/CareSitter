using CareSitter.Contracts.Services;
using CareSitter.Modules.Payments.Application;
using CareSitter.Modules.Payments.Application.Refunds;
using CareSitter.Modules.Payments.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.Modules.Payments.UnitTests;

public sealed class WalletServiceTests
{
    [Fact]
    public async Task Settle_CreditsTheAssignedCaregiverUserWalletExactlyOnce()
    {
        var bookingId = Guid.NewGuid();
        var caregiverProfileId = Guid.NewGuid();
        var caregiverUserId = Guid.NewGuid();
        await using var db = CreateDbContext();
        var service = new WalletService(
            new WalletLedgerStore(db, new DisputeLookupStub(false)),
            new DisputeLookupStub(false),
            new PeopleLookupStub(caregiverProfileId, caregiverUserId),
            new RefundCoordinatorStub());

        var first = await service.SettleAsync(
            bookingId, caregiverProfileId, escrowAmount: 100_000, platformFeeAmount: 15_000);
        var second = await service.SettleAsync(
            bookingId, caregiverProfileId, escrowAmount: 100_000, platformFeeAmount: 15_000);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        var wallet = await db.WalletAccounts.SingleAsync(x =>
            x.UserId == caregiverUserId && x.AccountType == "CAREGIVER");
        Assert.Equal(85_000, wallet.AvailableBalance);

        var earning = await db.LedgerEntries.SingleAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "CAREGIVER_EARNING");
        Assert.Equal($"wallet:caregiver:{caregiverUserId}", earning.CreditAccount);
    }

    [Fact]
    public async Task Settle_RejectsAnUnknownCaregiverProfile()
    {
        await using var db = CreateDbContext();
        var service = new WalletService(
            new WalletLedgerStore(db, new DisputeLookupStub(false)),
            new DisputeLookupStub(false),
            new PeopleLookupStub(Guid.NewGuid(), null),
            new RefundCoordinatorStub());

        var result = await service.SettleAsync(
            Guid.NewGuid(), Guid.NewGuid(), escrowAmount: 100_000, platformFeeAmount: 15_000);

        Assert.True(result.IsFailure);
        Assert.Equal("payments.caregiver_not_found", result.Error.Code);
        Assert.Empty(await db.LedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task PromotionSubsidy_IsRecordedExactlyOnce()
    {
        var bookingId = Guid.NewGuid();
        await using var db = CreateDbContext();
        var service = new WalletService(
            new WalletLedgerStore(db, new DisputeLookupStub(false)),
            new DisputeLookupStub(false),
            new PeopleLookupStub(Guid.NewGuid(), null), new RefundCoordinatorStub());

        var first = await service.RecordPromotionSubsidyAsync(bookingId, 100_000);
        var retry = await service.RecordPromotionSubsidyAsync(bookingId, 100_000);

        Assert.True(first.IsSuccess);
        Assert.True(retry.IsSuccess);
        var entry = await db.LedgerEntries.SingleAsync(x =>
            x.BookingId == bookingId && x.TransactionType == "PROMOTION_SUBSIDY");
        Assert.Equal(100_000, entry.Amount);
        Assert.Equal("revenue:platform", entry.DebitAccount);
        Assert.Equal("escrow:platform", entry.CreditAccount);
        Assert.Equal("POSTED", entry.Status);
    }

    private static PaymentsDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<PaymentsDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new PaymentsDbContext(options);
    }

    private sealed class DisputeLookupStub(bool hasOpenDispute) : IDisputeLookupService
    {
        public Task<bool> HasOpenDisputeAsync(Guid bookingId, CancellationToken ct = default) =>
            Task.FromResult(hasOpenDispute);
    }

    private sealed class RefundCoordinatorStub : IOriginalPaymentRefundCoordinator
    {
        public Task<CareSitter.SharedKernel.Results.Result<OriginalPaymentRefundOutcome>> EnsureRefundAsync(
            Guid bookingId,
            Guid customerId,
            long? amount,
            string reason,
            CancellationToken ct = default) =>
            Task.FromResult<CareSitter.SharedKernel.Results.Result<OriginalPaymentRefundOutcome>>(
                new OriginalPaymentRefundOutcome(OriginalPaymentRefundState.Pending));
    }

    private sealed class PeopleLookupStub(Guid caregiverProfileId, Guid? caregiverUserId)
        : IPeopleLookupService
    {
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default) =>
            Task.FromResult(caregiverId == caregiverProfileId ? caregiverUserId : null);

        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid userId, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid userId, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default) =>
            throw new NotSupportedException();
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default) =>
            throw new NotSupportedException();
    }
}
