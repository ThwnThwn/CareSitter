using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal sealed class BookingCheckoutJobs(IBookingCheckoutStore checkouts, IBookingJobNotifier notifier)
{
    public async Task AlertLateCheckinsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-BookingLifecyclePolicy.LateCheckinGraceMinutes);
        foreach (var booking in await checkouts.RecordLateCheckinsAsync(cutoff))
            await notifier.LateCheckinAsync(booking);
    }

    public async Task AutoRequestCheckoutExpiredShiftsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddMinutes(-BookingLifecyclePolicy.ShiftEndCheckoutGraceMinutes);
        await foreach (var change in checkouts.RequestExpiredCheckoutsAsync(cutoff))
            await notifier.CheckoutRequestedAsync(change);
    }

    public async Task AutoConfirmPendingCheckoutsAsync()
    {
        var cutoff = DateTimeOffset.UtcNow.AddHours(-BookingLifecyclePolicy.AutoConfirmCheckoutHours);
        await foreach (var change in checkouts.ConfirmPendingCheckoutsAsync(cutoff))
            await notifier.AutoConfirmedAsync(change);
    }


}
