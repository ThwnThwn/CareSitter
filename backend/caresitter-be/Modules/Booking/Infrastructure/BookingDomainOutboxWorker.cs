using CareSitter.Modules.Booking.Application;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingDomainOutboxWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<BookingSideEffectOptions> options,
    ILogger<BookingDomainOutboxWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = TimeSpan.FromSeconds(
            Math.Clamp(options.Value.PollIntervalSeconds, 1, 300));
        using var timer = new PeriodicTimer(interval);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                await scope.ServiceProvider
                    .GetRequiredService<BookingDomainOutboxDispatcher>()
                    .DispatchPendingAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Booking domain outbox polling failed.");
            }

            if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
        }
    }
}
