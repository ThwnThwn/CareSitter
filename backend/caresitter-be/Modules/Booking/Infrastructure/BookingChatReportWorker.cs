using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using CareSitter.Modules.Booking.Application;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>Continues report-to-ticket work after API restart or temporary Support failure.</summary>
internal sealed class BookingChatReportWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<BookingChatOptions> options,
    ILogger<BookingChatReportWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(
            Math.Clamp(options.Value.DispatcherPollIntervalSeconds, 1, 300)));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                await scope.ServiceProvider.GetRequiredService<BookingChatReportDispatcher>()
                    .DispatchPendingAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Booking chat report polling failed.");
            }
            if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
        }
    }
}
