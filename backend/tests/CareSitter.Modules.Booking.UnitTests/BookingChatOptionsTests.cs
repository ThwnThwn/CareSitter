using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatOptionsTests
{
    [Fact]
    public void Destructive_and_external_side_effects_are_opt_in_by_default()
    {
        var options = new BookingChatOptions();

        Assert.False(options.PushEnabled);
        Assert.False(options.PurgeEnabled);
    }
}
