using CareSitter.Modules.Booking.Application;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Quét booking_chat_outbox theo chu kỳ. Outbox đã commit nằm trong PostgreSQL nên
/// tắt worker hoặc restart API không làm mất signal; khi bật lại sẽ gửi tiếp.
/// </summary>
internal sealed class BookingChatDispatchWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<BookingChatOptions> options,
    ILogger<BookingChatDispatchWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = TimeSpan.FromSeconds(
            Math.Clamp(options.Value.DispatcherPollIntervalSeconds, 1, 300));
        using var timer = new PeriodicTimer(interval);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                var dispatcher = scope.ServiceProvider
                    .GetRequiredService<IBookingChatDispatcher>();
                await dispatcher.DispatchPendingAsync(
                    scope.ServiceProvider.GetRequiredService<IOptions<BookingChatOptions>>()
                        .Value.DispatcherBatchSize, stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception exception)
            {
                logger.LogError(exception, "Booking chat outbox polling failed.");
            }

            if (!await timer.WaitForNextTickAsync(stoppingToken))
                break;
        }
    }
}

