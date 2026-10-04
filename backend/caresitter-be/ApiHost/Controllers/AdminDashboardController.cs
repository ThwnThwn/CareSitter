using CareSitter.Contracts.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CareSitter.ApiHost.Controllers;

[ApiController]
[Authorize(Roles = "ADMIN")]
[Route("api/v1/admin/dashboard")]
public sealed class AdminDashboardController(
    IAdminBookingReader bookingReader,
    IAdminPeopleReader peopleReader,
    IAdminPaymentsReader paymentsReader,
    IAdminSupportReader supportReader,
    IAdminIdentityReader identityReader) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var vietnamOffset = TimeSpan.FromHours(7);
        var localNow = DateTimeOffset.UtcNow.ToOffset(vietnamOffset);
        var localStart = new DateTimeOffset(localNow.Year, localNow.Month, localNow.Day,
            0, 0, 0, vietnamOffset).ToUniversalTime();
        var localEnd = localStart.AddDays(1);

        var bookingTask = bookingReader.GetDashboardSnapshotAsync(localStart, localEnd, ct);
        var peopleTask = peopleReader.GetDashboardSnapshotAsync(ct);
        var paymentsTask = paymentsReader.GetDashboardSnapshotAsync(ct);
        var supportTask = supportReader.GetDashboardSnapshotAsync(ct);
        var activeUsersTask = identityReader.CountActiveUsersAsync(ct);

        await Task.WhenAll(bookingTask, peopleTask, paymentsTask, supportTask, activeUsersTask);

        var booking = await bookingTask;
        var people = await peopleTask;
        var payments = await paymentsTask;
        var support = await supportTask;
        var activeUsers = await activeUsersTask;

        var workItems = payments.WorkItems
            .Concat(people.WorkItems)
            .Concat(support.WorkItems)
            .OrderByDescending(x => x.Priority == "CRITICAL")
            .ThenByDescending(x => x.Priority == "HIGH")
            .ThenBy(x => x.CreatedAt)
            .ThenBy(x => x.Id)
            .Take(12)
            .ToArray();

        return Ok(new
        {
            generatedAt = DateTimeOffset.UtcNow,
            metrics = new
            {
                bookingsToday = booking.BookingsToday,
                pendingKyc = people.PendingKyc,
                pendingPayouts = payments.PendingPayouts,
                openTickets = support.OpenTickets,
                openDisputes = support.OpenDisputes,
                manualPayments = payments.ManualPayments,
                activeUsers
            },
            bookingStatuses = booking.StatusCounts,
            workItems
        });
    }
}
