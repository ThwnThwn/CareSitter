using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Booking.Domain;

public enum BookingChatLifecycleState
{
    Unavailable,
    Open,
    PostShiftGrace,
    ReadOnly,
    Purged
}

public enum BookingChatLifecycleReason
{
    None,
    ConversationNotReady,
    CaregiverNotAssigned,
    BookingState,
    AdminBlocked,
    DisputeLocked,
    Crisis,
    BookingClosed,
    GraceDeadlineMissing,
    GraceExpired,
    Purged
}

public sealed record BookingChatLifecycleContext(
    BookingStatus BookingStatus,
    bool ConversationExists,
    bool HasAssignedCaregiver,
    DateTimeOffset ServerNow,
    DateTimeOffset? WriteClosesAt = null,
    DateTimeOffset? DisputeLockedAt = null,
    DateTimeOffset? WriteBlockedAt = null,
    DateTimeOffset? PurgedAt = null);

public sealed record BookingChatLifecycleDecision(
    BookingChatLifecycleState State,
    bool CanRead,
    bool CanSend,
    BookingChatLifecycleReason Reason);

/// <summary>
/// Suy vòng đời chat từ booking và các mốc đã snapshot. Caller vẫn phải kiểm
/// ownership/epoch trước khi dùng quyết định này để cấp quyền đọc.
/// </summary>
public static class BookingChatLifecyclePolicy
{
    public static readonly TimeSpan DefaultPostShiftGrace = TimeSpan.FromHours(24);

    public static BookingChatLifecycleDecision Evaluate(BookingChatLifecycleContext context)
    {
        if (context.PurgedAt is not null)
            return Decision(BookingChatLifecycleState.Purged, false,
                BookingChatLifecycleReason.Purged);

        if (!context.ConversationExists)
            return Decision(BookingChatLifecycleState.Unavailable, false,
                BookingChatLifecycleReason.ConversationNotReady);

        if (context.DisputeLockedAt is not null ||
            context.BookingStatus == BookingStatus.Disputed)
            return Decision(BookingChatLifecycleState.ReadOnly, true,
                BookingChatLifecycleReason.DisputeLocked);

        if (context.WriteBlockedAt is not null)
            return Decision(BookingChatLifecycleState.ReadOnly, true,
                BookingChatLifecycleReason.AdminBlocked);

        if (context.BookingStatus == BookingStatus.Crisis)
            return Decision(BookingChatLifecycleState.ReadOnly, true,
                BookingChatLifecycleReason.Crisis);

        if (context.BookingStatus is BookingStatus.Cancelled or BookingStatus.Refunded)
            return Decision(BookingChatLifecycleState.ReadOnly, true,
                BookingChatLifecycleReason.BookingClosed);

        if (!context.HasAssignedCaregiver)
            return Decision(BookingChatLifecycleState.Unavailable, true,
                BookingChatLifecycleReason.CaregiverNotAssigned);

        if (context.BookingStatus is BookingStatus.CaregiverAccepted or
            BookingStatus.CaregiverEnRoute or BookingStatus.InProgress)
            return Decision(BookingChatLifecycleState.Open, true,
                BookingChatLifecycleReason.None);

        if (context.BookingStatus is BookingStatus.CheckoutPendingReview or
            BookingStatus.Completed)
        {
            if (context.WriteClosesAt is null)
                return Decision(BookingChatLifecycleState.ReadOnly, true,
                    BookingChatLifecycleReason.GraceDeadlineMissing);

            return context.ServerNow < context.WriteClosesAt.Value
                ? Decision(BookingChatLifecycleState.PostShiftGrace, true,
                    BookingChatLifecycleReason.None)
                : Decision(BookingChatLifecycleState.ReadOnly, true,
                    BookingChatLifecycleReason.GraceExpired);
        }

        return Decision(BookingChatLifecycleState.Unavailable, true,
            BookingChatLifecycleReason.BookingState);
    }

    public static Result<DateTimeOffset> SnapshotWriteClosesAt(
        DateTimeOffset? existingWriteClosesAt,
        DateTimeOffset graceStartedAt,
        TimeSpan? gracePeriod = null)
    {
        if (existingWriteClosesAt is not null)
            return existingWriteClosesAt.Value;

        var duration = gracePeriod ?? DefaultPostShiftGrace;
        if (duration <= TimeSpan.Zero)
            return Error.Validation("booking.chat.grace_period",
                "Khoảng nhắn sau ca phải lớn hơn 0.");

        return graceStartedAt.Add(duration);
    }

    private static BookingChatLifecycleDecision Decision(
        BookingChatLifecycleState state,
        bool canRead,
        BookingChatLifecycleReason reason) =>
        new(state, canRead, state is BookingChatLifecycleState.Open or
            BookingChatLifecycleState.PostShiftGrace, reason);
}
