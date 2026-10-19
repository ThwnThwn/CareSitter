using System.Globalization;
using System.Security.Cryptography;
using System.Text;
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

internal sealed class BookingChatService(
    BookingDbContext db,
    ICurrentUser currentUser,
    IPeopleLookupService people,
    IOptions<BookingChatOptions> options,
    IDataProtectionProvider dataProtection) : IBookingChatService
{
    private const int MaxPageSize = 100;
    private const int MaxBodyBytes = 8192;
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
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();

        var now = DateTimeOffset.UtcNow;
        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null)
        {
            var unavailable = BookingChatLifecyclePolicy.Evaluate(new(
                booking.Status, false, booking.CaregiverId is not null, now));
            return new BookingChatMetadataResponse(
                _options.Enabled, bookingId, null, null, 0, 0,
                ToApi(unavailable.State), false, false, ToApi(unavailable.Reason),
                now, null, 0, 0, 0, []);
        }

        var epoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (access.Role == "CAREGIVER" &&
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
                ToApi(decision.State), false, false, ToApi(decision.Reason),
                now, conversation.WriteClosesAt, 0, 0, 0, []);
        }

        var lastRead = 0L;
        var otherRead = 0L;
        var unread = 0;
        if (epoch is not null)
        {
            lastRead = await db.BookingChatReadCursors.AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.UserId == userId)
                .Select(x => (long?)x.LastReadSequence)
                .SingleOrDefaultAsync(ct) ?? 0;
            var otherUserId = access.Role == "CUSTOMER" ? epoch.CaregiverUserId : booking.CustomerId;
            otherRead = await db.BookingChatReadCursors.AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.UserId == otherUserId)
                .Select(x => (long?)x.LastReadSequence)
                .SingleOrDefaultAsync(ct) ?? 0;
            unread = await db.BookingChatMessages.AsNoTracking()
                .CountAsync(x => x.ConversationId == conversation.Id && x.EpochId == epoch.Id &&
                    x.Sequence > lastRead && x.SenderUserId != null &&
                    x.SenderUserId != userId, ct);
        }

        var canSend = _options.Enabled && decision.CanSend && epoch is not null;
        return new BookingChatMetadataResponse(
            _options.Enabled, bookingId, conversation.Id, epoch?.Id,
            conversation.ScopeVersion, conversation.ChangeVersion,
            ToApi(decision.State), decision.CanRead, canSend,
            canSend ? "none" : ToApi(decision.Reason), now,
            conversation.WriteClosesAt, lastRead, otherRead, unread,
            canSend ? GetTemplates(access.Role, booking.Status) : []);
    }

    public async Task<Result<BookingChatMessagesResponse>> GetMessagesAsync(
        Guid bookingId, string? afterCursor, string? beforeCursor, int limit,
        CancellationToken ct = default)
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

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();

        var currentEpoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (access.Role == "CAREGIVER" &&
            (currentEpoch is null || currentEpoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();

        var direction = beforeCursor is null ? "after" : "before";
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
        if (access.Role == "CAREGIVER")
            allowed = allowed.Where(x => x.EpochId == currentEpoch!.Id);

        var allowedHigh = await allowed.Select(x => (long?)x.Sequence).MaxAsync(ct) ?? 0;
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
            messages.Select(x => ToResponse(x, userId)).ToList(),
            ProtectCursor(new(conversation.Id, userId, conversation.ScopeVersion,
                "after", nextPosition, upperBound)),
            messages.Count == 0 ? null : ProtectCursor(new(conversation.Id, userId,
                conversation.ScopeVersion, "before", first, upperBound)),
            hasMoreAfter, hasMoreBefore, upperBound, conversation.ScopeVersion);
    }

    public async Task<Result<BookingChatMessageResponse>> SendAsync(
        Guid bookingId, Guid idempotencyKey, BookingChatSendRequest request,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();
        if (!_options.Enabled) return BookingChatErrors.Disabled();
        if (idempotencyKey == Guid.Empty)
            return BookingChatErrors.InvalidRequest("Idempotency-Key phải là UUID hợp lệ.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();
        var epoch = await db.BookingChatEpochs.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_epochs WHERE conversation_id = {conversation.Id} AND ended_at IS NULL FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (epoch is null) return BookingChatErrors.NotReady();
        if (access.Role == "CAREGIVER" && epoch.CaregiverUserId != userId)
            return BookingChatErrors.NotFound();

        var prepared = PrepareMessage(request, access.Role, booking.Status);
        if (prepared.IsFailure) return prepared.Error;
        var payloadHash = ComputePayloadHash(prepared.Value, request.ExpectedEpochId);
        var existing = await db.BookingChatMessages.SingleOrDefaultAsync(x =>
            x.ConversationId == conversation.Id && x.SenderUserId == userId &&
            x.IdempotencyKey == idempotencyKey, ct);
        if (existing is not null)
        {
            if (existing.PayloadHash != payloadHash)
                return BookingChatErrors.IdempotencyConflict();
            if (access.Role == "CAREGIVER" && existing.EpochId != epoch.Id)
                return BookingChatErrors.NotFound();
            await tx.CommitAsync(ct);
            return ToResponse(existing, userId);
        }

        if (request.ExpectedEpochId != epoch.Id)
            return BookingChatErrors.ScopeChanged();
        var now = DateTimeOffset.UtcNow;
        var lifecycle = BookingChatLifecyclePolicy.Evaluate(new(
            booking.Status, true, booking.CaregiverId is not null, now,
            conversation.WriteClosesAt, conversation.DisputeLockedAt,
            conversation.WriteBlockedAt, conversation.PurgedAt));
        if (!lifecycle.CanSend)
            return BookingChatErrors.ReadOnly(ToApi(lifecycle.Reason));

        var next = conversation.AppendMessage(now);
        var message = BookingChatMessage.CreateUser(
            conversation.Id, epoch.Id, next.Sequence, userId, access.Role,
            prepared.Value.Kind, prepared.Value.TemplateKey,
            prepared.Value.TemplateVersion, prepared.Value.TemplateParamsJson,
            prepared.Value.Body, idempotencyKey, payloadHash, now);
        db.BookingChatMessages.Add(message);
        db.BookingChatOutbox.AddRange(
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                message.Id, "USER_MESSAGE_CREATED", next.ChangeVersion, now),
            BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                message.Id, "USER_MESSAGE_CREATED", next.ChangeVersion, now));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return ToResponse(message, userId);
    }

    public async Task<Result<BookingChatReadResponse>> MarkReadAsync(
        Guid bookingId, BookingChatReadRequest request, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();
        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();

        var epoch = await db.BookingChatEpochs.SingleOrDefaultAsync(
            x => x.Id == request.EpochId && x.ConversationId == conversation.Id, ct);
        if (epoch is null) return BookingChatErrors.ScopeChanged();
        if (access.Role == "CAREGIVER" &&
            (epoch.EndedAt is not null || epoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();
        var message = await db.BookingChatMessages.AsNoTracking().SingleOrDefaultAsync(
            x => x.Id == request.LastReadMessageId && x.ConversationId == conversation.Id &&
                x.EpochId == epoch.Id, ct);
        if (message is null)
            return BookingChatErrors.InvalidRequest("Tin nhắn đánh dấu đã đọc không thuộc phạm vi hiện tại.");

        var now = DateTimeOffset.UtcNow;
        var read = await db.BookingChatReadCursors.SingleOrDefaultAsync(x =>
            x.ConversationId == conversation.Id && x.EpochId == epoch.Id && x.UserId == userId, ct);
        var changed = false;
        if (read is null)
        {
            read = BookingChatReadCursor.Create(conversation.Id, epoch.Id, userId,
                message.Sequence, now);
            db.BookingChatReadCursors.Add(read);
            changed = true;
        }
        else
        {
            changed = read.Advance(message.Sequence, now);
        }

        if (changed)
        {
            var version = conversation.AdvanceChangeVersion(now);
            db.BookingChatOutbox.AddRange(
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, booking.CustomerId,
                    null, "READ_CHANGED", version, now),
                BookingChatOutboxEvent.Create(conversation.Id, epoch.Id, epoch.CaregiverUserId,
                    null, "READ_CHANGED", version, now));
            await db.SaveChangesAsync(ct);
        }
        await tx.CommitAsync(ct);
        return new BookingChatReadResponse(epoch.Id, read.LastReadSequence,
            conversation.ChangeVersion, changed);
    }

    public async Task<Result<BookingChatReportResponse>> ReportMessageAsync(
        Guid bookingId, Guid messageId, BookingChatReportRequest request,
        CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();
        var reason = request.Reason?.Trim();
        if (messageId == Guid.Empty || string.IsNullOrWhiteSpace(reason) || reason.Length > 500)
            return BookingChatErrors.InvalidRequest("Lý do báo cáo phải từ 1 đến 500 ký tự.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var booking = await db.Bookings.FromSqlInterpolated(
            $"SELECT * FROM booking.bookings WHERE id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();
        var reportLockKey = $"booking-chat-report:{messageId}:{userId}";
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT pg_advisory_xact_lock(hashtextextended({reportLockKey}, 0))", ct);
        var conversation = await db.BookingChatConversations.FromSqlInterpolated(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {bookingId} FOR UPDATE")
            .SingleOrDefaultAsync(ct);
        if (conversation is null) return BookingChatErrors.NotReady();
        if (conversation.PurgedAt is not null) return BookingChatErrors.Purged();
        var currentEpoch = await db.BookingChatEpochs.AsNoTracking()
            .SingleOrDefaultAsync(x => x.ConversationId == conversation.Id && x.EndedAt == null, ct);
        if (access.Role == "CAREGIVER" &&
            (currentEpoch is null || currentEpoch.CaregiverUserId != userId))
            return BookingChatErrors.NotFound();

        var messageQuery = db.BookingChatMessages.Where(x =>
            x.Id == messageId && x.ConversationId == conversation.Id && x.SenderUserId != null);
        if (access.Role == "CAREGIVER")
            messageQuery = messageQuery.Where(x => x.EpochId == currentEpoch!.Id);
        var message = await messageQuery.SingleOrDefaultAsync(ct);
        if (message is null)
            return BookingChatErrors.InvalidRequest("Tin nhắn không thuộc phạm vi bạn có thể báo cáo.");
        if (message.SenderUserId == userId)
            return BookingChatErrors.InvalidRequest("Chỉ có thể báo cáo tin nhắn của người còn lại.");
        var existing = await db.BookingChatReports.SingleOrDefaultAsync(x =>
            x.MessageId == message.Id && x.ReporterUserId == userId, ct);
        if (existing is not null)
        {
            await tx.CommitAsync(ct);
            return new BookingChatReportResponse(
                existing.Id, existing.Status, existing.SupportTicketId);
        }

        var now = DateTimeOffset.UtcNow;
        var report = BookingChatReport.Create(message.Id, userId, reason, now);
        conversation.PlaceLegalHold("Báo cáo tin nhắn đang chờ xử lý", now);
        db.BookingChatReports.Add(report);
        db.BookingChatActivityEvents.Add(BookingChatActivityEvent.Create(conversation.Id, userId,
            "MESSAGE_REPORTED", reason, now));
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new BookingChatReportResponse(report.Id, report.Status, report.SupportTicketId);
    }

    public async Task<Result<BookingChatReportResponse>> GetReportAsync(
        Guid bookingId, Guid reportId, CancellationToken ct = default)
    {
        if (currentUser.UserId is not { } userId)
            return BookingChatErrors.Unauthenticated();

        var booking = await db.Bookings.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == bookingId, ct);
        if (booking is null) return BookingChatErrors.NotFound();
        var access = await ResolveAccessAsync(booking, userId, ct);
        if (access is null) return BookingChatErrors.NotFound();

        var conversation = await db.BookingChatConversations.AsNoTracking()
            .SingleOrDefaultAsync(x => x.BookingId == bookingId, ct);
        if (conversation is null) return BookingChatErrors.NotFound();

        var reportQuery = db.BookingChatReports.AsNoTracking().Where(report =>
            report.Id == reportId && report.ReporterUserId == userId &&
            db.BookingChatMessages.Any(message => message.Id == report.MessageId &&
                message.ConversationId == conversation.Id));
        if (access.Role == "CAREGIVER")
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

    private async Task<ChatAccess?> ResolveAccessAsync(
        Domain.Booking booking, Guid userId, CancellationToken ct)
    {
        if (booking.CustomerId == userId && currentUser.IsInRole("CUSTOMER"))
            return new("CUSTOMER");
        if (!currentUser.IsInRole("CAREGIVER") || booking.CaregiverId is not { } caregiverId)
            return null;
        return await people.IsCaregiverForBookingAsync(caregiverId, userId, ct)
            ? new ChatAccess("CAREGIVER")
            : null;
    }

    private static Result<PreparedMessage> PrepareMessage(
        BookingChatSendRequest request, string role, BookingStatus status)
    {
        var kind = request.Kind?.Trim().ToLowerInvariant();
        if (kind == "text")
        {
            if (request.TemplateKey is not null || request.TemplateVersion is not null ||
                request.TemplateParams is not null)
                return BookingChatErrors.InvalidRequest("Tin text không được chứa thông tin template.");
            var normalized = (request.Text ?? string.Empty).Trim().Normalize(NormalizationForm.FormC);
            if (string.IsNullOrWhiteSpace(normalized))
                return BookingChatErrors.InvalidRequest("Nội dung tin nhắn không được để trống.");
            if (normalized.EnumerateRunes().Count() > 2000 ||
                Encoding.UTF8.GetByteCount(normalized) > MaxBodyBytes)
                return BookingChatErrors.InvalidRequest("Tin nhắn vượt quá giới hạn 2.000 ký tự.");
            if (normalized.Any(ch => char.IsControl(ch) && ch is not '\r' and not '\n' and not '\t'))
                return BookingChatErrors.InvalidRequest("Tin nhắn chứa ký tự điều khiển không hợp lệ.");
            return new PreparedMessage("text", normalized, null, null, null);
        }

        if (kind != "quick_message" || string.IsNullOrWhiteSpace(request.TemplateKey) ||
            request.TemplateVersion != 1 || request.Text is not null)
            return BookingChatErrors.InvalidRequest("Tin nhắn nhanh không hợp lệ.");
        var available = GetTemplates(role, status);
        var template = available.SingleOrDefault(x => x.Key == request.TemplateKey);
        if (template is null)
            return BookingChatErrors.InvalidRequest("Mẫu tin nhắn không khả dụng ở trạng thái hiện tại.");

        var parameters = new SortedDictionary<string, string>(StringComparer.Ordinal);
        if (request.TemplateParams is not null)
        {
            foreach (var parameter in request.TemplateParams)
                parameters[parameter.Key] = parameter.Value;
        }
        var body = template.Body;
        if (template.AllowedMinutes is { } allowedMinutes)
        {
            if (parameters.Count != 1 || !parameters.TryGetValue("minutes", out var rawMinutes) ||
                !int.TryParse(rawMinutes, NumberStyles.None, CultureInfo.InvariantCulture,
                    out var minutes) || !allowedMinutes.Contains(minutes))
                return BookingChatErrors.InvalidRequest("Số phút dự kiến phải là 5, 10, 15 hoặc 20.");
            body = body.Replace("{minutes}", minutes.ToString(CultureInfo.InvariantCulture),
                StringComparison.Ordinal);
        }
        else if (parameters.Count != 0)
        {
            return BookingChatErrors.InvalidRequest("Mẫu tin nhắn không nhận tham số.");
        }
        return new PreparedMessage("quick_message", body, template.Key, template.Version,
            JsonSerializer.Serialize(parameters));
    }

    private static IReadOnlyList<BookingChatTemplateResponse> GetTemplates(
        string role, BookingStatus status)
    {
        if (status is BookingStatus.CheckoutPendingReview or BookingStatus.Completed)
            return
            [
                new("common.thanks", 1, "Cảm ơn bạn."),
                new("common.items_received", 1, "Tôi đã nhận đủ đồ dùng.")
            ];
        if (role == "CAREGIVER")
        {
            if (status == BookingStatus.CaregiverAccepted)
                return
                [
                    new("caregiver.accepted_on_time", 1, "Tôi đã nhận lịch và sẽ đến đúng giờ."),
                    new("caregiver.confirm_address", 1, "Bạn xác nhận giúp tôi địa chỉ nhé.")
                ];
            if (status == BookingStatus.CaregiverEnRoute)
                return
                [
                    new("caregiver.en_route", 1, "Tôi đang trên đường đến."),
                    new("caregiver.arrival_eta", 1,
                        "Tôi sắp tới, dự kiến khoảng {minutes} phút nữa.", [5, 10, 15, 20]),
                    new("caregiver.waiting", 1, "Tôi đang đợi tại điểm hẹn."),
                    new("caregiver.pickup_help", 1, "Tôi cần bạn hướng dẫn thêm về điểm đón.")
                ];
            if (status == BookingStatus.InProgress)
                return [new("caregiver.arrived", 1, "Tôi đã đến nơi.")];
        }
        else
        {
            if (status == BookingStatus.CaregiverAccepted)
                return
                [
                    new("customer.use_booking_address", 1, "Bạn cứ đến theo địa chỉ trong lịch nhé."),
                    new("customer.call_on_arrival", 1, "Vui lòng gọi khi bạn đến."),
                    new("customer.meet_at_address", 1, "Tôi sẽ ra đón.")
                ];
            if (status == BookingStatus.CaregiverEnRoute)
                return
                [
                    new("customer.acknowledged", 1, "Tôi đã nhận được thông báo."),
                    new("customer.need_more_time", 1, "Tôi cần thêm ít phút.")
                ];
        }
        return [];
    }

    private static string ComputePayloadHash(PreparedMessage message, Guid expectedEpochId)
    {
        var canonical = string.Join('\n', message.Kind, message.Body,
            message.TemplateKey ?? string.Empty,
            message.TemplateVersion?.ToString(CultureInfo.InvariantCulture) ?? string.Empty,
            message.TemplateParamsJson ?? string.Empty, expectedEpochId.ToString("N"));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)))
            .ToLowerInvariant();
    }

    private BookingChatMessageResponse ToResponse(BookingChatMessage message, Guid userId)
    {
        IReadOnlyDictionary<string, string>? parameters = null;
        if (!string.IsNullOrWhiteSpace(message.TemplateParams))
        {
            parameters = JsonSerializer.Deserialize<Dictionary<string, string>>(
                message.TemplateParams!);
        }
        return new(message.Id, message.EpochId, message.Sequence,
            message.SenderUserId, message.SenderRole, message.Kind,
            message.TemplateKey, message.TemplateVersion, parameters,
            message.BodySnapshot, message.CreatedAt, message.SenderUserId == userId);
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

    private static string ToApi(BookingChatLifecycleState state) => state switch
    {
        BookingChatLifecycleState.PostShiftGrace => "post_shift_grace",
        _ => state.ToString().ToLowerInvariant()
    };

    private static string ToApi(BookingChatLifecycleReason reason) => reason switch
    {
        BookingChatLifecycleReason.None => "none",
        BookingChatLifecycleReason.ConversationNotReady => "conversation_not_ready",
        BookingChatLifecycleReason.CaregiverNotAssigned => "caregiver_not_assigned",
        BookingChatLifecycleReason.BookingState => "booking_state",
        BookingChatLifecycleReason.AdminBlocked => "admin_blocked",
        BookingChatLifecycleReason.DisputeLocked => "dispute_locked",
        BookingChatLifecycleReason.BookingClosed => "booking_closed",
        BookingChatLifecycleReason.GraceDeadlineMissing => "grace_deadline_missing",
        BookingChatLifecycleReason.GraceExpired => "grace_expired",
        _ => reason.ToString().ToLowerInvariant()
    };

    private sealed record ChatAccess(string Role);
    private sealed record PreparedMessage(
        string Kind,
        string Body,
        string? TemplateKey,
        int? TemplateVersion,
        string? TemplateParamsJson);
    private sealed record CursorPayload(
        Guid ConversationId,
        Guid UserId,
        long ScopeVersion,
        string Direction,
        long Position,
        long UpperBound);
}
