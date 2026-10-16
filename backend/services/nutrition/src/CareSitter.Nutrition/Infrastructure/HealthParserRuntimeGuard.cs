using Microsoft.Extensions.Options;

namespace CareSitter.Nutrition.Infrastructure;

internal sealed class HealthParserRuntimeGuard : IDisposable
{
    private readonly SemaphoreSlim _concurrency;
    private readonly TimeProvider _time;
    private readonly int _dailyBudget;
    private readonly object _budgetLock = new();
    private DateOnly _budgetDate;
    private int _attempts;

    public HealthParserRuntimeGuard(IOptions<HealthParserOptions> options)
        : this(options.Value, TimeProvider.System) { }

    internal HealthParserRuntimeGuard(HealthParserOptions options, TimeProvider time)
    {
        _concurrency = new SemaphoreSlim(options.MaxConcurrency, options.MaxConcurrency);
        _dailyBudget = options.DailyBudget;
        _time = time;
        _budgetDate = DateOnly.FromDateTime(_time.GetUtcNow().UtcDateTime);
    }

    public async ValueTask<IDisposable> EnterAsync(CancellationToken ct)
    {
        await _concurrency.WaitAsync(ct);
        return new Releaser(_concurrency);
    }

    public bool TryConsumeAttempt()
    {
        lock (_budgetLock)
        {
            var today = DateOnly.FromDateTime(_time.GetUtcNow().UtcDateTime);
            if (today != _budgetDate) { _budgetDate = today; _attempts = 0; }
            if (_attempts >= _dailyBudget) return false;
            _attempts++;
            return true;
        }
    }

    public void Dispose() => _concurrency.Dispose();

    private sealed class Releaser(SemaphoreSlim semaphore) : IDisposable
    {
        private SemaphoreSlim? _semaphore = semaphore;
        public void Dispose() => Interlocked.Exchange(ref _semaphore, null)?.Release();
    }
}
