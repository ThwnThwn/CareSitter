using CareSitter.Modules.Booking.Domain;

namespace CareSitter.Modules.Booking.UnitTests;

public sealed class BookingChatLifecyclePolicyTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 10, 17, 8, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(BookingStatus.CaregiverAccepted)]
    [InlineData(BookingStatus.CaregiverEnRoute)]
    [InlineData(BookingStatus.InProgress)]
    public void Assigned_active_booking_has_open_chat(BookingStatus status)
    {
        var decision = Evaluate(status);

        Assert.Equal(BookingChatLifecycleState.Open, decision.State);
        Assert.True(decision.CanRead);
        Assert.True(decision.CanSend);
        Assert.Equal(BookingChatLifecycleReason.None, decision.Reason);
    }

    [Theory]
    [InlineData(BookingStatus.Draft)]
    [InlineData(BookingStatus.PendingPayment)]
    [InlineData(BookingStatus.PaymentReconciliationPending)]
    [InlineData(BookingStatus.NeedsManualReview)]
    [InlineData(BookingStatus.Confirmed)]
    [InlineData(BookingStatus.MatchingFailed)]
    public void Pre_assignment_states_do_not_allow_sending(BookingStatus status)
    {
        var decision = Evaluate(status);

        Assert.Equal(BookingChatLifecycleState.Unavailable, decision.State);
        Assert.False(decision.CanSend);
        Assert.Equal(BookingChatLifecycleReason.BookingState, decision.Reason);
    }

    [Fact]
    public void Grace_uses_the_fixed_snapshot_and_closes_at_the_exact_deadline()
    {
        var close = Now.AddHours(24);
        var before = Evaluate(BookingStatus.Completed,
            writeClosesAt: close, serverNow: close.AddTicks(-1));
        var atDeadline = Evaluate(BookingStatus.Completed,
            writeClosesAt: close, serverNow: close);

        Assert.Equal(BookingChatLifecycleState.PostShiftGrace, before.State);
        Assert.True(before.CanSend);
        Assert.Equal(BookingChatLifecycleState.ReadOnly, atDeadline.State);
        Assert.False(atDeadline.CanSend);
        Assert.Equal(BookingChatLifecycleReason.GraceExpired, atDeadline.Reason);
    }

    [Fact]
    public void Missing_grace_deadline_fails_closed()
    {
        var decision = Evaluate(BookingStatus.CheckoutPendingReview);

        Assert.Equal(BookingChatLifecycleState.ReadOnly, decision.State);
        Assert.Equal(BookingChatLifecycleReason.GraceDeadlineMissing, decision.Reason);
    }

    [Fact]
    public void Purge_then_dispute_then_admin_block_take_priority()
    {
        var purged = Evaluate(BookingStatus.Disputed, purgedAt: Now,
            disputeLockedAt: Now, writeBlockedAt: Now);
        var disputed = Evaluate(BookingStatus.Completed,
            disputeLockedAt: Now, writeBlockedAt: Now);
        var blocked = Evaluate(BookingStatus.InProgress, writeBlockedAt: Now);

        Assert.Equal(BookingChatLifecycleState.Purged, purged.State);
        Assert.False(purged.CanRead);
        Assert.Equal(BookingChatLifecycleReason.DisputeLocked, disputed.Reason);
        Assert.Equal(BookingChatLifecycleReason.AdminBlocked, blocked.Reason);
    }

    [Fact]
    public void Resolved_dispute_does_not_reopen_chat()
    {
        var decision = Evaluate(BookingStatus.Completed,
            writeClosesAt: Now.AddDays(1), disputeLockedAt: Now.AddHours(-1));

        Assert.Equal(BookingChatLifecycleState.ReadOnly, decision.State);
        Assert.Equal(BookingChatLifecycleReason.DisputeLocked, decision.Reason);
    }

    [Fact]
    public void Crisis_is_read_only_but_can_reopen_after_returning_to_in_progress()
    {
        var crisis = Evaluate(BookingStatus.Crisis);
        var recovered = Evaluate(BookingStatus.InProgress);

        Assert.Equal(BookingChatLifecycleReason.Crisis, crisis.Reason);
        Assert.False(crisis.CanSend);
        Assert.True(recovered.CanSend);
    }

    [Fact]
    public void Missing_current_caregiver_keeps_history_readable_but_disables_send()
    {
        var decision = Evaluate(BookingStatus.InProgress, hasAssignedCaregiver: false);

        Assert.Equal(BookingChatLifecycleState.Unavailable, decision.State);
        Assert.True(decision.CanRead);
        Assert.False(decision.CanSend);
        Assert.Equal(BookingChatLifecycleReason.CaregiverNotAssigned, decision.Reason);
    }

    [Fact]
    public void Existing_grace_deadline_is_never_extended()
    {
        var existing = Now.AddHours(3);

        var result = BookingChatLifecyclePolicy.SnapshotWriteClosesAt(
            existing, Now.AddDays(1), TimeSpan.FromDays(7));

        Assert.True(result.IsSuccess);
        Assert.Equal(existing, result.Value);
    }

    [Fact]
    public void First_checkout_snapshots_the_configured_grace_and_rejects_invalid_duration()
    {
        var result = BookingChatLifecyclePolicy.SnapshotWriteClosesAt(
            null, Now, TimeSpan.FromHours(24));
        var invalid = BookingChatLifecyclePolicy.SnapshotWriteClosesAt(
            null, Now, TimeSpan.Zero);

        Assert.Equal(Now.AddHours(24), result.Value);
        Assert.True(invalid.IsFailure);
        Assert.Equal("booking.chat.grace_period", invalid.Error.Code);
    }

    private static BookingChatLifecycleDecision Evaluate(
        BookingStatus status,
        bool conversationExists = true,
        bool hasAssignedCaregiver = true,
        DateTimeOffset? serverNow = null,
        DateTimeOffset? writeClosesAt = null,
        DateTimeOffset? disputeLockedAt = null,
        DateTimeOffset? writeBlockedAt = null,
        DateTimeOffset? purgedAt = null) =>
        BookingChatLifecyclePolicy.Evaluate(new BookingChatLifecycleContext(
            status,
            conversationExists,
            hasAssignedCaregiver,
            serverNow ?? Now,
            writeClosesAt,
            disputeLockedAt,
            writeBlockedAt,
            purgedAt));
}
