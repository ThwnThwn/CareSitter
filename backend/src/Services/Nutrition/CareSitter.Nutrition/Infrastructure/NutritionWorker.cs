using CareSitter.Nutrition.Application;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class NutritionWorker(IServiceScopeFactory scopes, ILogger<NutritionWorker> logger,
    INutritionFeatures features) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                if (features.Enabled && features.AssessmentsEnabled)
                {
                    await using var scope = scopes.CreateAsyncScope();
                    var store = scope.ServiceProvider.GetRequiredService<INutritionStore>();
                    if (await store.ClaimAsync(stoppingToken) is { } job)
                    {
                        await scope.ServiceProvider.GetRequiredService<AssessmentProcessor>().ProcessAsync(job, stoppingToken);
                        continue;
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception e)
            {
                // Log only type: provider/DB messages may contain sensitive inputs.
                logger.LogWarning("Nutrition worker attempt failed ({ErrorType}); lease recovery will retry.", e.GetType().Name);
            }
            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
        }
    }
}
