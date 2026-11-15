using CareSitter.Modules.Booking.Application;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatRetentionWorker(
    IServiceScopeFactory scopeFactory,
    IOptions<BookingChatOptions> options,
    ILogger<BookingChatRetentionWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(
            Math.Clamp(options.Value.RetentionPollIntervalMinutes, 5, 1_440)));
        while (!stoppingToken.IsCancellationRequested)
        {
            if (options.Value.PurgeEnabled)
            {
                try
                {
                    using var scope = scopeFactory.CreateScope();
                    var result = await scope.ServiceProvider
                        .GetRequiredService<BookingChatRetentionService>()
                        .RunAsync(DateTimeOffset.UtcNow, dryRun: false,
                            options.Value.DispatcherBatchSize, stoppingToken);
                    if (result.ConversationIds.Count > 0)
                        logger.LogInformation("Purged {Count} expired booking chats.",
                            result.ConversationIds.Count);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception exception)
                {
                    logger.LogError(exception, "Booking chat retention run failed.");
                }
            }
            if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
        }
    }
}
