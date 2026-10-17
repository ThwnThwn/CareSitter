using CareSitter.Modules.Booking.Application;
using CareSitter.Contracts.Services;
using BookingEntity = CareSitter.Modules.Booking.Domain.Booking;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingCheckoutJobsTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Each_committed_checkout_is_notified_before_the_next_candidate_is_processed(bool confirm)
    {
        var trace = new List<string>();
        var store = new CheckoutStore(trace);
        var jobs = new BookingCheckoutJobs(store, new Notifier(trace));
        if (confirm) await jobs.AutoConfirmPendingCheckoutsAsync();
        else await jobs.AutoRequestCheckoutExpiredShiftsAsync();
        Assert.Equal(new[] { "persist:1", "notify:1", "persist:2", "notify:2" }, trace);
    }

    [Fact]
    public async Task A_later_candidate_failure_does_not_suppress_the_notice_for_an_already_committed_checkout()
    {
        var trace = new List<string>();
        var jobs = new BookingCheckoutJobs(new CheckoutStore(trace, failAfterFirst: true), new Notifier(trace));
        await Assert.ThrowsAsync<InvalidOperationException>(() => jobs.AutoConfirmPendingCheckoutsAsync());
        Assert.Equal(new[] { "persist:1", "notify:1" }, trace);
    }

    [Fact]
    public async Task Late_checkin_notices_are_sent_after_the_warning_is_saved()
    {
        var trace = new List<string>();
        await new BookingCheckoutJobs(new CheckoutStore(trace), new Notifier(trace)).AlertLateCheckinsAsync();
        Assert.Equal(new[] { "persist:1", "notify:1" }, trace);
    }

    private sealed class CheckoutStore(List<string> trace, bool failAfterFirst = false) : IBookingCheckoutStore
    {
        public Task<IReadOnlyList<BookingEntity>> RecordLateCheckinsAsync(DateTimeOffset cutoff, CancellationToken ct = default)
        {
            trace.Add("persist:1");
            return Task.FromResult<IReadOnlyList<BookingEntity>>([Booking()]);
        }
        public IAsyncEnumerable<BookingJobChange> RequestExpiredCheckoutsAsync(DateTimeOffset cutoff, CancellationToken ct = default) => Changes();
        public IAsyncEnumerable<BookingJobChange> ConfirmPendingCheckoutsAsync(DateTimeOffset cutoff, CancellationToken ct = default) => Changes();
        private async IAsyncEnumerable<BookingJobChange> Changes()
        {
            await Task.CompletedTask;
            trace.Add("persist:1");
            yield return new(Booking(), "checkout_pending_review", DateTimeOffset.UtcNow);
            if (failAfterFirst) throw new InvalidOperationException("Next candidate failed.");
            trace.Add("persist:2");
            yield return new(Booking(), "checkout_pending_review", DateTimeOffset.UtcNow);
        }
        private static BookingEntity Booking() => BookingEntity.Create(Guid.NewGuid(), Guid.NewGuid(),
            Guid.NewGuid(), Guid.NewGuid(), DateTimeOffset.UtcNow, DateTimeOffset.UtcNow.AddHours(1)).Value;
    }
    private sealed class Notifier(List<string> trace) : IBookingJobNotifier
    {
        private int _count;
        public Task LateCheckinAsync(BookingEntity booking, CancellationToken ct = default) => Notify();
        public Task CheckoutRequestedAsync(BookingJobChange change, CancellationToken ct = default) => Notify();
        public Task AutoConfirmedAsync(BookingJobChange change, CancellationToken ct = default) => Notify();
        public Task RefundedAsync(BookingEntity booking, OriginalPaymentRefundOutcome outcome,
            CancellationToken ct = default) => throw new NotSupportedException();
        private Task Notify() { trace.Add($"notify:{++_count}"); return Task.CompletedTask; }
    }
}
