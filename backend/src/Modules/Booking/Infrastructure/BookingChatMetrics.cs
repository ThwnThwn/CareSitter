using System.Diagnostics.Metrics;

namespace CareSitter.Modules.Booking.Infrastructure;

/// <summary>
/// Số liệu vận hành cho chat theo booking. Chỉ đếm signal và đo độ sâu/độ tuổi
/// backlog; không ghi conversation ID, user ID hay nội dung tin nhắn vào metric.
/// </summary>
public sealed class BookingChatMetrics
{
    private readonly Counter<long> _signalsDispatched;
    private readonly Counter<long> _signalsDropped;
    private readonly Counter<long> _dispatchFailures;
    private long _backlog;
    private double _oldestPendingSeconds;

    public BookingChatMetrics(IMeterFactory meters)
    {
        var meter = meters.Create("CareSitter.BookingChat");
        _signalsDispatched = meter.CreateCounter<long>("booking_chat_signals_dispatched_total");
        _signalsDropped = meter.CreateCounter<long>("booking_chat_signals_dropped_total");
        _dispatchFailures = meter.CreateCounter<long>("booking_chat_dispatch_failures_total");
        meter.CreateObservableGauge("booking_chat_outbox_backlog", () => _backlog);
        meter.CreateObservableGauge("booking_chat_outbox_oldest_seconds",
            () => _oldestPendingSeconds);
    }

    public void Dispatched(string kind) => _signalsDispatched.Add(1,
        new KeyValuePair<string, object?>("kind", kind));

    public void Dropped(string reason) => _signalsDropped.Add(1,
        new KeyValuePair<string, object?>("reason", reason));

    public void Failed() => _dispatchFailures.Add(1);

    /// <summary>Cập nhật backlog mỗi lượt quét để cảnh báo outbox age.</summary>
    public void ObserveBacklog(long pending, TimeSpan? oldestAge)
    {
        Interlocked.Exchange(ref _backlog, pending);
        Interlocked.Exchange(ref _oldestPendingSeconds,
            oldestAge is { } age ? Math.Max(0, age.TotalSeconds) : 0);
    }
}
