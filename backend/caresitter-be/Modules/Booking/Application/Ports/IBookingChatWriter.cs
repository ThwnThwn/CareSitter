using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.Application;

internal interface IBookingChatWriter
{
    Task EnsureFirstEpochAsync(Domain.Booking booking, Guid caregiverUserId,
        DateTimeOffset occurredAt, CancellationToken ct = default);

    Task RecordSystemTransitionAsync(Domain.Booking booking, string sourceEventType,
        string bodySnapshot, DateTimeOffset occurredAt,
        BookingChatTransitionEffect effect = BookingChatTransitionEffect.None,
        CancellationToken ct = default);
}

[Flags]
internal enum BookingChatTransitionEffect
{
    None = 0,
    StartPostShiftGrace = 1,
    LockForDispute = 2,
    ScheduleRetention = 4
}

public sealed class BookingChatOptions
{
    public const string SectionName = "BookingChat";
    public bool Enabled { get; set; }
    public int PostShiftGraceHours { get; set; } = 24;
    public int RetentionDays { get; set; } = 180;
    public bool PurgeEnabled { get; set; }

    /// <summary>Chu kỳ quét outbox chat; tách khỏi chu kỳ của Payments/Identity.</summary>
    public int DispatcherPollIntervalSeconds { get; set; } = 5;

    /// <summary>Thời gian giữ quyền xử lý một signal trước khi runner khác được nhận lại.</summary>
    public int DispatcherLeaseSeconds { get; set; } = 30;

    public int DispatcherBatchSize { get; set; } = 50;

    /// <summary>Số lượt thử tối đa trước khi chuyển sang DEAD_LETTER để đối soát.</summary>
    public int DispatcherMaxAttempts { get; set; } = 8;

    public int DispatcherRetryDelaySeconds { get; set; } = 15;
}
