using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatUserBlockTests
{
    [Fact]
    public void Block_unblock_and_reblock_are_idempotent()
    {
        var now = DateTimeOffset.UtcNow;
        var block = BookingChatUserBlock.Create(
            Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), now);

        Assert.False(block.Block(now.AddSeconds(1)));
        Assert.True(block.Unblock(now.AddMinutes(1)));
        Assert.False(block.Unblock(now.AddMinutes(2)));
        Assert.True(block.Block(now.AddMinutes(3)));
        Assert.Null(block.UnblockedAt);
        Assert.Equal(now.AddMinutes(3), block.BlockedAt);
    }

    [Fact]
    public void Cannot_block_self()
    {
        var userId = Guid.NewGuid();

        Assert.Throws<ArgumentException>(() => BookingChatUserBlock.Create(
            Guid.NewGuid(), userId, userId, DateTimeOffset.UtcNow));
    }
}
