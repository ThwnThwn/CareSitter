using CareSitter.Modules.Booking.Infrastructure;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatAdminCursorCodecTests
{
    [Fact]
    public void Cursor_round_trips_timestamp_and_tie_breaker()
    {
        var timestamp = DateTimeOffset.Parse("2026-10-18T03:45:12.1234567+07:00");
        var id = Guid.NewGuid();

        var valid = BookingChatAdminCursorCodec.TryDecode(
            BookingChatAdminCursorCodec.Encode(timestamp, id), out var decodedAt, out var decodedId);

        Assert.True(valid);
        Assert.Equal(timestamp, decodedAt);
        Assert.Equal(id, decodedId);
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-base64")]
    [InlineData("bm90LWFuLWFkbWluLWN1cnNvcg==")]
    public void Invalid_cursor_is_rejected(string cursor)
    {
        Assert.False(BookingChatAdminCursorCodec.TryDecode(cursor, out _, out _));
    }
}
