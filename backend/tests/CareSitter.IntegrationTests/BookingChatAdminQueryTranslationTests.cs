using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace CareSitter.IntegrationTests;

public sealed class BookingChatAdminQueryTranslationTests
{
    [Fact]
    public void Composite_admin_cursor_translates_for_postgresql()
    {
        var options = new DbContextOptionsBuilder<BookingDbContext>()
            .UseNpgsql("Host=localhost;Database=translation_only")
            .Options;
        using var db = new BookingDbContext(options);
        var timestamp = DateTimeOffset.UtcNow;
        var id = Guid.NewGuid();

        var sql = db.BookingChatConversations.Where(x => x.UpdatedAt < timestamp ||
            x.UpdatedAt == timestamp && x.Id.CompareTo(id) < 0).ToQueryString();

        Assert.Contains("updated_at", sql);
        Assert.Contains("id", sql);
    }

    [Fact]
    public void Report_and_user_filters_translate_for_postgresql()
    {
        var options = new DbContextOptionsBuilder<BookingDbContext>()
            .UseNpgsql("Host=localhost;Database=translation_only")
            .Options;
        using var db = new BookingDbContext(options);
        var userId = Guid.NewGuid();

        var sql = db.BookingChatConversations.Where(conversation =>
            db.BookingChatReports.Any(report => report.Status == "DEAD_LETTER" &&
                db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                    message.ConversationId == conversation.Id)) &&
            (db.Bookings.Any(booking => booking.Id == conversation.BookingId &&
                booking.CustomerId == userId) ||
             db.BookingChatEpochs.Any(epoch => epoch.ConversationId == conversation.Id &&
                epoch.CaregiverUserId == userId)))
            .ToQueryString();

        Assert.Contains("EXISTS", sql);
        Assert.Contains("DEAD_LETTER", sql);
    }
}
