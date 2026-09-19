using CareSitter.Modules.Booking.Controllers;
using CareSitter.Modules.Payments.Controllers;
using Microsoft.AspNetCore.Authorization;

namespace CareSitter.IntegrationTests;

public sealed class PaymentSecurityContractTests
{
    [Fact]
    public void GlobalLedgerRequiresAdminRole()
    {
        var method = typeof(PaymentsController).GetMethod(nameof(PaymentsController.ListLedger));

        var authorization = Assert.Single(method!.GetCustomAttributes(typeof(AuthorizeAttribute), true)
            .Cast<AuthorizeAttribute>());
        Assert.Equal("ADMIN", authorization.Roles);
    }

    [Fact]
    public void BookingControllerDoesNotExposeDirectPaymentConfirmation()
    {
        var directConfirmation = typeof(BookingsController).GetMethod("ConfirmPayment");

        Assert.Null(directConfirmation);
    }
}
