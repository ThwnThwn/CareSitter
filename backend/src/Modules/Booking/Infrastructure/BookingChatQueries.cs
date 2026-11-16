using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CareSitter.Modules.Booking.Infrastructure;

internal sealed class BookingChatQueries(
    BookingDbContext db,
    ICurrentUser currentUser,
    BookingChatParticipantAccess participantAccess,
    IOptions<BookingChatOptions> options,
    IDataProtectionProvider dataProtection) : IBookingChatQueries
{
    private const int MaxPageSize = 100;
    private readonly BookingChatOptions _options = options.Value;
    private readonly IDataProtector _cursorProtector = dataProtection.CreateProtector(
        "CareSitter.BookingChat.Cursor.v1");

    public async Task<Result<BookingChatMetadataResponse>> GetMetadataAsync(
        Guid bookingId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();

        var now = DateTimeOffset.UtcNow;
        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null)
        {
            var unavailable = BookingChatLifecyclePolicy.Evaluate(new(
                booking.Status, false, booking.CaregiverId is not null, now));
            return new BookingChatMetadataResponse(
                _options.Enabled, bookingId, null, null, 0, 0,
                BookingChatResponses.ToApi(unavailable.State), false, false, BookingChatResponses.ToApi(unavailable.Reason),
                now, null, 0, 0, 0, false, false, []);
        }

        var epoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (role == "CAREGIVER" &&
            (epoch is null || epoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();

        var decision = BookingChatLifecyclePolicy.Evaluate(new(
            booking.Status, true, booking.CaregiverId is not null, now,
            conversation.WriteClosesAt, conversation.DisputeLockedAt,
            conversation.WriteBlockedAt, conversation.PurgedAt));
        if (conversation.PurgedAt is not null)
        {
            return new BookingChatMetadataResponse(
                _options.Enabled, bookingId, conversation.Id, epoch?.Id,
                conversation.ScopeVersion, conversation.ChangeVersion,
                BookingChatResponses.ToApi(decision.State), false, false, BookingChatResponses.ToApi(decision.Reason),
                now, conversation.WriteClosesAt, 0, 0, 0, false, false, []);
        }

        var lastRead = 0L;
        var otherRead = 0L;
        var unread = 0;
        var isBlockedByMe = false;
        var isBlockedByOther = false;
        if (epoch is not null)
        {
            lastRead = await db.BookingChatReadCursors.AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.UserId == userId)
                .Select(x => (long?)x.LastReadSequence)
                .SingleOrDefaultAsync(ct) ?? 0;
            var otherUserId = role == "CUSTOMER" ? epoch.CaregiverUserId : booking.CustomerId;
            otherRead = await db.BookingChatReadCursors.AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.UserId == otherUserId)
                .Select(x => (long?)x.LastReadSequence)
                .SingleOrDefaultAsync(ct) ?? 0;
            unread = await db.BookingChatMessages.AsNoTracking()
                .CountAsync(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.Sequence > lastRead && x.SenderUserId != null &&
                    x.SenderUserId != userId, ct);
            isBlockedByMe = await db.BookingChatUserBlocks.AsNoTracking().AnyAsync(x =>
                x.ConversationId == conversation.Id && x.BlockerUserId == userId &&
                x.BlockedUserId == otherUserId && x.UnblockedAt == null, ct);
            isBlockedByOther = await db.BookingChatUserBlocks.AsNoTracking().AnyAsync(x =>
                x.ConversationId == conversation.Id && x.BlockerUserId == otherUserId &&
                x.BlockedUserId == userId && x.UnblockedAt == null, ct);
        }

        var canSend = _options.Enabled && decision.CanSend && epoch is not null &&
            !isBlockedByMe && !isBlockedByOther;
        var readOnlyReason = canSend
            ? "none"
            : isBlockedByMe
                ? "blocked_by_you"
                : isBlockedByOther
                    ? "blocked_by_other"
                    : BookingChatResponses.ToApi(decision.Reason);
        return new BookingChatMetadataResponse(
            _options.Enabled, bookingId, conversation.Id, epoch?.Id,
            conversation.ScopeVersion, conversation.ChangeVersion,
            BookingChatResponses.ToApi(decision.State), decision.CanRead, canSend, readOnlyReason, now,
            conversation.WriteClosesAt, lastRead, otherRead, unread,
            isBlockedByMe, isBlockedByOther,
            canSend ? BookingChatMessageContent.GetTemplates(role, booking.Status) : []);
    }

    public Task<Result<BookingChatMessagesResponse>> GetMessagesAsync(
        Guid bookingId, string? afterCursor, string? beforeCursor, int limit,
        CancellationToken ct = default) =>
        GetMessagesCoreAsync(bookingId, afterCursor, beforeCursor, limit, null, ct);

    public Task<Result<BookingChatMessagesResponse>> ResumeMessagesAsync(
        Guid bookingId, Guid anchorMessageId, string direction, long scopeVersion,
        int limit, CancellationToken ct = default) =>
        GetMessagesCoreAsync(bookingId, null, null, limit,
            new(anchorMessageId, direction, scopeVersion), ct);

    private async Task<Result<BookingChatMessagesResponse>> GetMessagesCoreAsync(
        Guid bookingId, string? afterCursor, string? beforeCursor, int limit,
        ResumeAnchor? resume, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();
        if ((afterCursor is not null && string.IsNullOrWhiteSpace(afterCursor)) ||
            (beforeCursor is not null && string.IsNullOrWhiteSpace(beforeCursor)))
            return BookingChatErrors.CursorInvalid();
        if (!string.IsNullOrWhiteSpace(afterCursor) && !string.IsNullOrWhiteSpace(beforeCursor))
            return BookingChatErrors.InvalidRequest("Không dùng đồng thời afterCursor và beforeCursor.");
        if (limit is < 1 or > MaxPageSize)
            return BookingChatErrors.InvalidRequest("limit phải nằm trong khoảng 1-100.");
        if (resume is not null && (resume.Direction is not ("after" or "before") ||
            resume.ScopeVersion < 1 || resume.MessageId == Guid.Empty))
            return BookingChatErrors.CursorInvalid();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();

        var currentEpoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (role == "CAREGIVER" &&
            (currentEpoch is null || currentEpoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();

        var direction = resume?.Direction ?? (beforeCursor is null ? "after" : "before");
        CursorPayload? cursor = null;
        if (afterCursor is not null || beforeCursor is not null)
        {
            cursor = TryReadCursor(afterCursor ?? beforeCursor!);
            if (cursor is null || cursor.ConversationId != conversation.Id ||
                cursor.UserId != userId || cursor.Direction != direction)
                return BookingChatErrors.CursorInvalid();
            if (cursor.ScopeVersion != conversation.ScopeVersion)
                return BookingChatErrors.ScopeChanged();
        }

        IQueryable<BookingChatMessage> allowed = db.BookingChatMessages.AsNoTracking()
            .Where(x => x.ConversationId == conversation.Id);
        if (role == "CAREGIVER")
            allowed = allowed.Where(x => x.EpochId == currentEpoch!.Id);

        var allowedHigh = await allowed.Select(x => (long?)x.Sequence).MaxAsync(ct) ?? 0;
        if (resume is not null)
        {
            if (resume.ScopeVersion != conversation.ScopeVersion)
                return BookingChatErrors.ScopeChanged();
            // Resolve the anchor only inside the caller's currently allowed epoch.
            // Raw Firestore positions never bypass the protected API cursor scope.
            var position = await allowed.Where(x => x.Id == resume.MessageId)
                .Select(x => (long?)x.Sequence).SingleOrDefaultAsync(ct);
            if (position is null) return BookingChatErrors.CursorInvalid();
            cursor = new(conversation.Id, userId, conversation.ScopeVersion,
                direction, position.Value, allowedHigh);
        }
        var upperBound = cursor?.UpperBound ?? allowedHigh;
        if (direction == "after" && cursor is not null && cursor.Position >= cursor.UpperBound)
            upperBound = allowedHigh;

        List<BookingChatMessage> messages;
        if (cursor is null)
        {
            messages = await allowed.Where(x => x.Sequence <= upperBound)
                .OrderByDescending(x => x.Sequence).Take(limit).ToListAsync(ct);
            messages.Reverse();
        }
        else if (direction == "after")
        {
            messages = await allowed
                .Where(x => x.Sequence > cursor.Position && x.Sequence <= upperBound)
                .OrderBy(x => x.Sequence).Take(limit).ToListAsync(ct);
        }
        else
        {
            messages = await allowed
                .Where(x => x.Sequence < cursor.Position && x.Sequence <= upperBound)
                .OrderByDescending(x => x.Sequence).Take(limit).ToListAsync(ct);
            messages.Reverse();
        }

        var first = messages.Count == 0 ? (cursor?.Position ?? 0) : messages[0].Sequence;
        var last = messages.Count == 0 ? (cursor?.Position ?? 0) : messages[^1].Sequence;
        var hasMoreBefore = messages.Count > 0 &&
            await allowed.AnyAsync(x => x.Sequence < first && x.Sequence <= upperBound, ct);
        var hasMoreAfter = messages.Count > 0 &&
            await allowed.AnyAsync(x => x.Sequence > last && x.Sequence <= upperBound, ct);
        var nextPosition = hasMoreAfter ? last : upperBound;

        return new BookingChatMessagesResponse(
            messages.Select(x => BookingChatResponses.ToMessage(x, userId)).ToList(),
            ProtectCursor(new(conversation.Id, userId, conversation.ScopeVersion,
                "after", nextPosition, upperBound)),
            messages.Count == 0 ? null : ProtectCursor(new(conversation.Id, userId,
                conversation.ScopeVersion, "before", first, upperBound)),
            hasMoreAfter, hasMoreBefore, upperBound, conversation.ScopeVersion);
    }

    public async Task<Result<BookingChatReportResponse>> GetReportAsync(
        Guid bookingId, Guid reportId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var role = await participantAccess.ResolveRoleAsync(booking, userId, ct);
        if (role is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null) return BookingChatErrors.NotFound();

        var reportQuery = db.BookingChatReports.AsNoTracking().Where(report =>
            report.Id == reportId && report.ReporterUserId == userId &&
            db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                message.ConversationId == conversation.Id));
        if (role == "CAREGIVER")
        {
            var epochId = await db.BookingChatEpochs.AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id && x.EndedAt == null &&
                    x.CaregiverUserId == userId)
                .Select(x => (Guid?)x.Id)
                .SingleOrDefaultAsync(ct);
            if (epochId is null) return BookingChatErrors.NotFound();
            reportQuery = reportQuery.Where(report => db.BookingChatMessages.Any(message =>
                message.Id == report.MessageId && message.EpochId == epochId.Value));
        }

        var report = await reportQuery.SingleOrDefaultAsync(ct);
        return report is null
            ? BookingChatErrors.NotFound()
            : new BookingChatReportResponse(
                report.Id, report.Status, report.SupportTicketId);
    }

    private string ProtectCursor(CursorPayload payload) =>
        Convert.ToBase64String(_cursorProtector.Protect(
            JsonSerializer.SerializeToUtf8Bytes(payload)));

    private CursorPayload? TryReadCursor(string token)
    {
        try
        {
            var protectedBytes = Convert.FromBase64String(token);
            return JsonSerializer.Deserialize<CursorPayload>(
                _cursorProtector.Unprotect(protectedBytes));
        }
        catch (Exception exception) when (exception is FormatException or
            CryptographicException or JsonException)
        {
            return null;
        }
    }

    private sealed record ResumeAnchor(Guid MessageId, string Direction, long ScopeVersion);
    private sealed record CursorPayload(
        Guid ConversationId,
        Guid UserId,
        long ScopeVersion,
        string Direction,
        long Position,
        long UpperBound);
}
