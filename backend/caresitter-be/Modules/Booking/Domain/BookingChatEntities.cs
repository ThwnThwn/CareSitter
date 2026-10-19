namespace CareSitter.Modules.Booking.Domain;

public sealed class BookingChatConversation
{
    private BookingChatConversation() { }

    private BookingChatConversation(Guid bookingId, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        BookingId = bookingId;
        LastSequence = 1;
        ChangeVersion = 1;
        ScopeVersion = 1;
        LastMessageAt = now;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }
    public Guid BookingId { get; private set; }
    public long LastSequence { get; private set; }
    public long ChangeVersion { get; private set; }
    public long ScopeVersion { get; private set; }
    public DateTimeOffset? LastMessageAt { get; private set; }
    public DateTimeOffset? GraceStartedAt { get; private set; }
    public DateTimeOffset? WriteClosesAt { get; private set; }
    public DateTimeOffset? DisputeLockedAt { get; private set; }
    public DateTimeOffset? WriteBlockedAt { get; private set; }
    public string? WriteBlockReason { get; private set; }
    public Guid? BlockedByUserId { get; private set; }
    public DateTimeOffset? RetainedUntil { get; private set; }
    public DateTimeOffset? HoldUntil { get; private set; }
    public DateTimeOffset? LegalHoldAt { get; private set; }
    public string? LegalHoldReason { get; private set; }
    public DateTimeOffset? LegalHoldReleasedAt { get; private set; }
    public DateTimeOffset? PurgedAt { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public static BookingChatConversation Create(Guid bookingId, DateTimeOffset now) =>
        new(bookingId, now);

    public (long Sequence, long ChangeVersion) AppendMessage(DateTimeOffset now)
    {
        LastSequence++;
        ChangeVersion++;
        LastMessageAt = now;
        UpdatedAt = now;
        return (LastSequence, ChangeVersion);
    }

    public void SnapshotGraceWindow(DateTimeOffset startedAt, TimeSpan gracePeriod)
    {
        if (WriteClosesAt is not null) return;
        GraceStartedAt = startedAt;
        WriteClosesAt = startedAt.Add(gracePeriod);
        UpdatedAt = startedAt;
    }

    public void LockForDispute(DateTimeOffset lockedAt)
    {
        DisputeLockedAt ??= lockedAt;
        UpdatedAt = lockedAt;
    }

    public void ScheduleRetention(DateTimeOffset closedAt, TimeSpan retention)
    {
        RetainedUntil ??= closedAt.Add(retention);
        UpdatedAt = closedAt;
    }

    public long AdvanceChangeVersion(DateTimeOffset now)
    {
        ChangeVersion++;
        UpdatedAt = now;
        return ChangeVersion;
    }

    public long BlockWrites(Guid adminUserId, string reason, DateTimeOffset now)
    {
        WriteBlockedAt = now;
        WriteBlockReason = reason;
        BlockedByUserId = adminUserId;
        return AdvanceChangeVersion(now);
    }

    public long UnblockWrites(DateTimeOffset now)
    {
        WriteBlockedAt = null;
        WriteBlockReason = null;
        BlockedByUserId = null;
        return AdvanceChangeVersion(now);
    }

    public void PlaceLegalHold(string reason, DateTimeOffset now)
    {
        LegalHoldAt ??= now;
        LegalHoldReason = reason;
        LegalHoldReleasedAt = null;
        UpdatedAt = now;
    }

    public long ReleaseLegalHold(DateTimeOffset now)
    {
        LegalHoldReleasedAt = now;
        HoldUntil = null;
        return AdvanceChangeVersion(now);
    }

    public void MarkPurged(DateTimeOffset now)
    {
        PurgedAt = now;
        UpdatedAt = now;
    }
}

public sealed class BookingChatActivityEvent
{
    private BookingChatActivityEvent() { }

    private BookingChatActivityEvent(Guid conversationId, Guid? actorUserId, string action,
        string? reason, DateTimeOffset createdAt)
    {
        Id = Guid.NewGuid();
        ConversationId = conversationId;
        ActorUserId = actorUserId;
        Action = action;
        Reason = reason;
        CreatedAt = createdAt;
    }

    public Guid Id { get; private set; }
    public Guid ConversationId { get; private set; }
    public Guid? ActorUserId { get; private set; }
    public string Action { get; private set; } = null!;
    public string? Reason { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static BookingChatActivityEvent Create(Guid conversationId, Guid? actorUserId,
        string action, string? reason, DateTimeOffset now) =>
        new(conversationId, actorUserId, action, reason, now);
}

public sealed class BookingChatReport
{
    private BookingChatReport() { }

    private BookingChatReport(Guid messageId, Guid reporterUserId, string reason, DateTimeOffset now)
    {
        Id = Guid.NewGuid();
        MessageId = messageId;
        ReporterUserId = reporterUserId;
        Reason = reason;
        Status = "PENDING";
        AvailableAt = now;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid Id { get; private set; }
    public Guid MessageId { get; private set; }
    public Guid ReporterUserId { get; private set; }
    public string Reason { get; private set; } = null!;
    public Guid? SupportTicketId { get; private set; }
    public string Status { get; private set; } = null!;
    public int Attempts { get; private set; }
    public DateTimeOffset AvailableAt { get; private set; }
    public DateTimeOffset? LeaseUntil { get; private set; }
    public Guid? ClaimToken { get; private set; }
    public string? LastError { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public static BookingChatReport Create(Guid messageId, Guid reporterUserId, string reason,
        DateTimeOffset now) => new(messageId, reporterUserId, reason, now);

    public void Claim(Guid token, DateTimeOffset now, DateTimeOffset leaseUntil)
    {
        Status = "PROCESSING";
        ClaimToken = token;
        LeaseUntil = leaseUntil;
        Attempts++;
        UpdatedAt = now;
    }

    public void Link(Guid ticketId, DateTimeOffset now)
    {
        SupportTicketId = ticketId;
        Status = "LINKED";
        ClaimToken = null;
        LeaseUntil = null;
        LastError = null;
        UpdatedAt = now;
    }

    public void Fail(string error, DateTimeOffset availableAt, DateTimeOffset now, bool deadLetter)
    {
        Status = deadLetter ? "DEAD_LETTER" : "FAILED";
        ClaimToken = null;
        LeaseUntil = null;
        AvailableAt = availableAt;
        LastError = error.Length <= 500 ? error : error[..500];
        UpdatedAt = now;
    }
}

public sealed class BookingChatEpoch
{
    private BookingChatEpoch() { }

    private BookingChatEpoch(Guid conversationId, Guid caregiverProfileId,
        Guid caregiverUserId, DateTimeOffset startedAt)
    {
        Id = Guid.NewGuid();
        ConversationId = conversationId;
        EpochNumber = 1;
        CaregiverProfileId = caregiverProfileId;
        CaregiverUserId = caregiverUserId;
        StartedAt = startedAt;
    }

    public Guid Id { get; private set; }
    public Guid ConversationId { get; private set; }
    public int EpochNumber { get; private set; }
    public Guid CaregiverProfileId { get; private set; }
    public Guid CaregiverUserId { get; private set; }
    public DateTimeOffset StartedAt { get; private set; }
    public DateTimeOffset? EndedAt { get; private set; }

    public static BookingChatEpoch CreateFirst(Guid conversationId, Guid caregiverProfileId,
        Guid caregiverUserId, DateTimeOffset startedAt) =>
        new(conversationId, caregiverProfileId, caregiverUserId, startedAt);
}

public sealed class BookingChatMessage
{
    private BookingChatMessage() { }

    private BookingChatMessage(Guid conversationId, Guid epochId, long sequence,
        Guid sourceEventId, string bodySnapshot, DateTimeOffset createdAt)
    {
        Id = Guid.NewGuid();
        ConversationId = conversationId;
        EpochId = epochId;
        Sequence = sequence;
        Kind = "system";
        BodySnapshot = bodySnapshot;
        SourceEventId = sourceEventId;
        CreatedAt = createdAt;
    }

    private BookingChatMessage(Guid conversationId, Guid epochId, long sequence,
        Guid senderUserId, string senderRole, string kind, string? templateKey,
        int? templateVersion, string? templateParams, string bodySnapshot,
        Guid idempotencyKey, string payloadHash, DateTimeOffset createdAt)
    {
        Id = Guid.NewGuid();
        ConversationId = conversationId;
        EpochId = epochId;
        Sequence = sequence;
        SenderUserId = senderUserId;
        SenderRole = senderRole;
        Kind = kind;
        TemplateKey = templateKey;
        TemplateVersion = templateVersion;
        TemplateParams = templateParams;
        BodySnapshot = bodySnapshot;
        IdempotencyKey = idempotencyKey;
        PayloadHash = payloadHash;
        CreatedAt = createdAt;
    }

    public Guid Id { get; private set; }
    public Guid ConversationId { get; private set; }
    public Guid EpochId { get; private set; }
    public long Sequence { get; private set; }
    public Guid? SenderUserId { get; private set; }
    public string? SenderRole { get; private set; }
    public string Kind { get; private set; } = null!;
    public string? TemplateKey { get; private set; }
    public int? TemplateVersion { get; private set; }
    public string? TemplateParams { get; private set; }
    public string BodySnapshot { get; private set; } = null!;
    public Guid? IdempotencyKey { get; private set; }
    public string? PayloadHash { get; private set; }
    public Guid? SourceEventId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static BookingChatMessage CreateSystem(Guid conversationId, Guid epochId,
        long sequence, Guid sourceEventId, string bodySnapshot, DateTimeOffset createdAt) =>
        new(conversationId, epochId, sequence, sourceEventId, bodySnapshot, createdAt);

    public static BookingChatMessage CreateUser(Guid conversationId, Guid epochId,
        long sequence, Guid senderUserId, string senderRole, string kind,
        string? templateKey, int? templateVersion, string? templateParams,
        string bodySnapshot, Guid idempotencyKey, string payloadHash,
        DateTimeOffset createdAt) =>
        new(conversationId, epochId, sequence, senderUserId, senderRole, kind,
            templateKey, templateVersion, templateParams, bodySnapshot,
            idempotencyKey, payloadHash, createdAt);
}

public sealed class BookingChatReadCursor
{
    private BookingChatReadCursor() { }

    private BookingChatReadCursor(Guid conversationId, Guid epochId, Guid userId,
        long sequence, DateTimeOffset now)
    {
        ConversationId = conversationId;
        EpochId = epochId;
        UserId = userId;
        LastReadSequence = sequence;
        UpdatedAt = now;
    }

    public Guid ConversationId { get; private set; }
    public Guid EpochId { get; private set; }
    public Guid UserId { get; private set; }
    public long LastReadSequence { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public static BookingChatReadCursor Create(Guid conversationId, Guid epochId,
        Guid userId, long sequence, DateTimeOffset now) =>
        new(conversationId, epochId, userId, sequence, now);

    public bool Advance(long sequence, DateTimeOffset now)
    {
        if (sequence <= LastReadSequence) return false;
        LastReadSequence = sequence;
        UpdatedAt = now;
        return true;
    }
}

public sealed class BookingChatOutboxEvent
{
    private BookingChatOutboxEvent() { }

    private BookingChatOutboxEvent(Guid conversationId, Guid epochId, Guid recipientUserId,
        Guid? messageId, string kind, long changeVersion, DateTimeOffset now)
    {
        EventId = Guid.NewGuid();
        ConversationId = conversationId;
        EpochId = epochId;
        RecipientUserId = recipientUserId;
        Kind = kind;
        ChangeVersion = changeVersion;
        MessageId = messageId;
        Status = "PENDING";
        AvailableAt = now;
        CreatedAt = now;
        UpdatedAt = now;
    }

    public Guid EventId { get; private set; }
    public Guid ConversationId { get; private set; }
    public Guid? EpochId { get; private set; }
    public Guid RecipientUserId { get; private set; }
    public string Kind { get; private set; } = null!;
    public long ChangeVersion { get; private set; }
    public Guid? MessageId { get; private set; }
    public string Status { get; private set; } = null!;
    public int Attempts { get; private set; }
    public DateTimeOffset AvailableAt { get; private set; }
    public DateTimeOffset? LeaseUntil { get; private set; }
    public string? LastError { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset UpdatedAt { get; private set; }

    public static BookingChatOutboxEvent Create(Guid conversationId, Guid epochId,
        Guid recipientUserId, Guid? messageId, string kind, long changeVersion,
        DateTimeOffset now) =>
        new(conversationId, epochId, recipientUserId, messageId, kind, changeVersion, now);

    /// <summary>
    /// Nhận xử lý một signal đang chờ. Lease chỉ dùng để giành quyền, không phải
    /// bằng chứng đã gửi: tín hiệu realtime chưa gửi được sẽ được thử lại.
    /// </summary>
    public void Claim(DateTimeOffset now, DateTimeOffset leaseUntil)
    {
        Status = "PROCESSING";
        LeaseUntil = leaseUntil;
        Attempts++;
        UpdatedAt = now;
    }

    public void MarkSent(DateTimeOffset now)
    {
        Status = "SENT";
        LeaseUntil = null;
        LastError = null;
        UpdatedAt = now;
    }

    /// <summary>Lỗi tạm thời: giữ nguyên row để dispatcher thử lại sau backoff.</summary>
    public void MarkFailed(string error, DateTimeOffset availableAt, DateTimeOffset now)
    {
        Status = "FAILED";
        LeaseUntil = null;
        LastError = Truncate(error);
        AvailableAt = availableAt;
        UpdatedAt = now;
    }

    /// <summary>Hết lượt thử: giữ row lại để đối soát, không xóa và không gửi tiếp.</summary>
    public void MarkDeadLetter(string error, DateTimeOffset now)
    {
        Status = "DEAD_LETTER";
        LeaseUntil = null;
        LastError = Truncate(error);
        UpdatedAt = now;
    }

    /// <summary>
    /// Bỏ signal vì lý do nghiệp vụ không thể khắc phục (conversation purge,
    /// epoch/booking không còn, người nhận đã mất quyền). Khác DEAD_LETTER:
    /// đây là kết quả đúng, không phải lỗi cần thử lại hay cần người xử lý.
    /// </summary>
    public void MarkDropped(string reason, DateTimeOffset now)
    {
        Status = "DROPPED";
        LeaseUntil = null;
        LastError = Truncate(reason);
        UpdatedAt = now;
    }

    private static string Truncate(string error) =>
        error.Length <= 500 ? error : error[..500];
}
