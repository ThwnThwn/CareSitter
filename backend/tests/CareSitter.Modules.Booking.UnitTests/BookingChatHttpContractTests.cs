using CareSitter.Modules.Booking.Controllers;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatHttpContractTests
{
    [Theory]
    [InlineData(nameof(AdminBookingChatController.Block))]
    [InlineData(nameof(AdminBookingChatController.Unblock))]
    [InlineData(nameof(AdminBookingChatController.ReleaseLegalHold))]
    public void Admin_mutations_use_put(string action)
    {
        var method = typeof(AdminBookingChatController).GetMethod(action)!;

        Assert.NotNull(method.GetCustomAttributes(typeof(HttpPutAttribute), false).SingleOrDefault());
        Assert.Empty(method.GetCustomAttributes(typeof(HttpPostAttribute), false));
    }

    [Fact]
    public void User_report_route_scopes_the_message_id()
    {
        var method = typeof(BookingChatController).GetMethod(nameof(BookingChatController.Report))!;
        var route = Assert.Single(method.GetCustomAttributes(typeof(HttpPostAttribute), false)
            .Cast<HttpPostAttribute>()).Template;

        Assert.Equal("messages/{messageId:guid}/reports", route);
    }
}
