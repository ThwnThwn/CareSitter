using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using CareSitter.Modules.Support.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
    [PostgresFact]
    public async Task Report_replay_returns_one_report_and_one_support_ticket()
    {
        await using var bookingDb = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(bookingDb, 1, false);
        var messageId = await bookingDb.BookingChatMessages
            .Where(x => x.ConversationId == seed.ConversationId)
            .Select(x => x.Id)
            .SingleAsync();
        await bookingDb.BookingChatMessages.Where(x => x.Id == messageId)
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(x => x.SenderUserId, seed.CaregiverUserId)
                .SetProperty(x => x.SenderRole, "CAREGIVER"));
        bookingDb.ChangeTracker.Clear();
        var customerChat = CreateChatService(bookingDb, seed.CustomerId, "CUSTOMER",
            seed.CaregiverProfileId, seed.CaregiverUserId);

        var first = await customerChat.ReportMessageAsync(seed.BookingId, messageId,
            new BookingChatReportRequest("Nội dung không phù hợp"));
        var replay = await customerChat.ReportMessageAsync(seed.BookingId, messageId,
            new BookingChatReportRequest("Lý do retry không tạo report mới"));

        Assert.True(first.IsSuccess, first.Error.Message);
        Assert.True(replay.IsSuccess, replay.Error.Message);
        Assert.Equal(first.Value.ReportId, replay.Value.ReportId);

        await using var supportDb = new SupportDbContext(
            new DbContextOptionsBuilder<SupportDbContext>()
                .UseNpgsql(Database.ConnectionString).Options);
        var tickets = new BookingChatSupportTicketService(supportDb);
        var request = new BookingChatReportTicketRequest(first.Value.ReportId, seed.CustomerId,
            seed.BookingId, seed.ConversationId, messageId, "Nội dung không phù hợp");
        var firstTicket = await tickets.CreateForBookingChatReportAsync(request);
        var replayTicket = await tickets.CreateForBookingChatReportAsync(request);

        Assert.Equal(firstTicket, replayTicket);
        Assert.Equal(1, await supportDb.BookingChatReportTicketSources
            .CountAsync(x => x.ReportId == first.Value.ReportId));
        Assert.Equal(1, await supportDb.SupportTickets.CountAsync(x => x.Id == firstTicket));

        var ownStatus = await customerChat.GetReportAsync(seed.BookingId, first.Value.ReportId);
        Assert.True(ownStatus.IsSuccess, ownStatus.Error.Message);
        var caregiverChat = CreateChatService(bookingDb, seed.CaregiverUserId, "CAREGIVER",
            seed.CaregiverProfileId, seed.CaregiverUserId);
        var otherParticipantStatus = await caregiverChat.GetReportAsync(
            seed.BookingId, first.Value.ReportId);
        Assert.True(otherParticipantStatus.IsFailure);
        Assert.Equal("booking.chat.not_found", otherParticipantStatus.Error.Code);
    }

    [PostgresFact]
    public async Task Admin_content_read_requires_context_and_records_ticket_in_audit()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 2, false);
        var adminId = seed.CustomerId;
        var admin = new BookingChatAdminService(db, new TestActor(adminId, "ADMIN"));

        var missingContext = await admin.GetMessagesAsync(seed.ConversationId,
            null, 50, " ", null);
        Assert.True(missingContext.IsFailure);
        Assert.Equal("booking.chat.invalid_request", missingContext.Error.Code);

        var ticketId = Guid.NewGuid();
        var page = await admin.GetMessagesAsync(seed.ConversationId,
            null, 50, "Điều tra report", ticketId);

        Assert.True(page.IsSuccess, page.Error.Message);
        Assert.Equal(2, page.Value.Items.Count);
        var audit = await db.BookingChatActivityEvents.AsNoTracking()
            .SingleAsync(x => x.ConversationId == seed.ConversationId &&
                x.Action == "ADMIN_MESSAGES_VIEWED");
        Assert.Equal(adminId, audit.ActorUserId);
        Assert.Contains("Điều tra report", audit.Reason);
        Assert.Contains(ticketId.ToString(), audit.Reason);
    }

    [PostgresFact]
    public async Task Admin_service_rejects_authenticated_non_admin_actor()
    {
        await using var db = CreateDb();
        var admin = new BookingChatAdminService(db,
            new TestActor(Guid.NewGuid(), "CUSTOMER"));

        var result = await admin.ListAsync(new BookingChatAdminListFilter(), null, 20);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.forbidden", result.Error.Code);
    }

    [PostgresFact]
    public async Task Admin_block_rejects_stale_expected_version()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 1, false);
        var admin = new BookingChatAdminService(db,
            new TestActor(seed.CustomerId, "ADMIN"));
        var version = await db.BookingChatConversations
            .Where(x => x.Id == seed.ConversationId)
            .Select(x => x.ChangeVersion)
            .SingleAsync();

        var stale = await admin.BlockAsync(seed.ConversationId,
            new BookingChatAdminBlockRequest(version - 1, "Điều tra report"));

        Assert.True(stale.IsFailure);
        Assert.Equal("booking.chat.scope_changed", stale.Error.Code);
        db.ChangeTracker.Clear();
        Assert.Null((await db.BookingChatConversations.AsNoTracking()
            .SingleAsync(x => x.Id == seed.ConversationId)).WriteBlockedAt);
    }

    [PostgresFact]
    public async Task Legal_hold_cannot_be_released_while_linked_support_ticket_is_active()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 1, false);
        var conversation = await db.BookingChatConversations
            .SingleAsync(x => x.Id == seed.ConversationId);
        conversation.PlaceLegalHold("Đang điều tra", DateTimeOffset.UtcNow);
        var messageId = await db.BookingChatMessages
            .Where(x => x.ConversationId == seed.ConversationId)
            .Select(x => x.Id).SingleAsync();
        var report = BookingChatReport.Create(messageId, seed.CustomerId,
            "Nội dung cần điều tra", DateTimeOffset.UtcNow);
        await using var supportDb = new SupportDbContext(
            new DbContextOptionsBuilder<SupportDbContext>()
                .UseNpgsql(Database.ConnectionString).Options);
        var ticketId = await new BookingChatSupportTicketService(supportDb)
            .CreateForBookingChatReportAsync(new BookingChatReportTicketRequest(
                report.Id, seed.CustomerId, seed.BookingId, seed.ConversationId,
                messageId, report.Reason));
        report.Link(ticketId, DateTimeOffset.UtcNow);
        db.BookingChatReports.Add(report);
        await db.SaveChangesAsync();
        var admin = new BookingChatAdminService(db,
            new TestActor(seed.CustomerId, "ADMIN"), new TestSupportTickets(false));

        var result = await admin.ReleaseLegalHoldAsync(seed.ConversationId,
            new BookingChatAdminBlockRequest(conversation.ChangeVersion, "Ticket còn mở"));

        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.legal_hold_active", result.Error.Code);
        db.ChangeTracker.Clear();
        Assert.Null((await db.BookingChatConversations.AsNoTracking()
            .SingleAsync(x => x.Id == seed.ConversationId)).LegalHoldReleasedAt);
    }

    private sealed class TestSupportTickets(bool resolved) : IBookingChatSupportTicketService
    {
        public Task<Guid> CreateForBookingChatReportAsync(
            BookingChatReportTicketRequest request, CancellationToken ct = default) =>
            Task.FromResult(Guid.NewGuid());

        public Task<bool> AreResolvedAsync(IReadOnlyCollection<Guid> ticketIds,
            CancellationToken ct = default) => Task.FromResult(resolved);
    }

    [PostgresFact]
    public async Task Admin_cursor_and_report_block_dead_letter_filters_cover_more_than_one_page()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, 0, false);
        var cutoff = DateTimeOffset.UtcNow.AddYears(5);
        await SeedAdminQueueAsync(seed.CustomerId, seed.CaregiverProfileId,
            seed.CaregiverUserId, cutoff, 105);
        var admin = new BookingChatAdminService(db,
            new TestActor(seed.CustomerId, "ADMIN"));

        var ids = new HashSet<Guid>();
        string? cursor = null;
        do
        {
            var page = await admin.ListAsync(new BookingChatAdminListFilter(From: cutoff),
                cursor, 40);
            Assert.True(page.IsSuccess, page.Error.Message);
            Assert.All(page.Value.Items, item => Assert.True(ids.Add(item.ConversationId)));
            cursor = page.Value.NextCursor;
        } while (cursor is not null);
        Assert.Equal(105, ids.Count);

        var reported = await admin.ListAsync(
            new BookingChatAdminListFilter(Reported: true, From: cutoff), null, 100);
        var blocked = await admin.ListAsync(
            new BookingChatAdminListFilter(Blocked: true, From: cutoff), null, 100);
        var deadLetter = await admin.ListAsync(
            new BookingChatAdminListFilter(DeadLetter: true, From: cutoff), null, 100);
        Assert.Equal(2, reported.Value.Items.Count);
        Assert.Single(blocked.Value.Items);
        Assert.Single(deadLetter.Value.Items);
        Assert.Equal(1, deadLetter.Value.Items[0].DeadLetterCount);
    }

    private async Task SeedAdminQueueAsync(Guid customerId, Guid caregiverProfileId,
        Guid caregiverUserId, DateTimeOffset updatedFrom, int count)
    {
        await using var connection = await Database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            CREATE TEMP TABLE booking_chat_admin_seed (
                n integer PRIMARY KEY,
                booking_id uuid NOT NULL,
                conversation_id uuid NOT NULL,
                epoch_id uuid NOT NULL,
                message_id uuid NOT NULL
            );

            INSERT INTO booking_chat_admin_seed
            SELECT n, gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()
            FROM generate_series(1, @count) n;

            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, address_id, service_type_id, caregiver_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount,
                customer_payable_amount)
            SELECT seed.booking_id, @customerId, beneficiary.id, address.id, service.id,
                   @caregiverProfileId,
                   now() + interval '30 days' + seed.n * interval '3 hours',
                   now() + interval '30 days 2 hours' + seed.n * interval '3 hours',
                   now() + interval '1 day', 'CANCELLED', 100000, 15000, 85000, 100000
            FROM booking_chat_admin_seed seed
            CROSS JOIN LATERAL (
                SELECT id FROM people.beneficiaries
                WHERE customer_id = @customerId ORDER BY id LIMIT 1
            ) beneficiary
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.addresses
                WHERE owner_user_id = @customerId ORDER BY id LIMIT 1
            ) address
            CROSS JOIN LATERAL (
                SELECT id FROM catalog.service_types ORDER BY id LIMIT 1
            ) service;

            INSERT INTO booking.booking_chat_conversations (
                id, booking_id, last_sequence, change_version, scope_version,
                write_blocked_at, write_block_reason, blocked_by_user_id,
                created_at, updated_at)
            SELECT conversation_id, booking_id, 1, 1, 1,
                   CASE WHEN n = 3 THEN @updatedFrom ELSE NULL END,
                   CASE WHEN n = 3 THEN 'Kiểm tra filter' ELSE NULL END,
                   CASE WHEN n = 3 THEN @customerId ELSE NULL END,
                   @updatedFrom, @updatedFrom + n * interval '1 second'
            FROM booking_chat_admin_seed;

            INSERT INTO booking.booking_chat_epochs (
                id, conversation_id, epoch_number, caregiver_profile_id,
                caregiver_user_id, started_at)
            SELECT epoch_id, conversation_id, 1, @caregiverProfileId,
                   @caregiverUserId, @updatedFrom
            FROM booking_chat_admin_seed;

            INSERT INTO booking.booking_chat_messages (
                id, conversation_id, epoch_id, sequence, sender_user_id, sender_role,
                kind, body_snapshot, idempotency_key, payload_hash, created_at)
            SELECT message_id, conversation_id, epoch_id, 1, @caregiverUserId,
                   'CAREGIVER', 'text', 'Admin pagination fixture', gen_random_uuid(),
                   repeat(md5(n::text), 2), @updatedFrom
            FROM booking_chat_admin_seed;

            INSERT INTO booking.booking_chat_reports (
                id, message_id, reporter_user_id, reason, status, attempts,
                available_at, last_error, created_at, updated_at)
            SELECT gen_random_uuid(), message_id, @customerId, 'Filter fixture',
                   CASE WHEN n = 2 THEN 'DEAD_LETTER' ELSE 'PENDING' END,
                   CASE WHEN n = 2 THEN 3 ELSE 0 END,
                   @updatedFrom,
                   CASE WHEN n = 2 THEN 'InjectedFailure' ELSE NULL END,
                   @updatedFrom, @updatedFrom
            FROM booking_chat_admin_seed
            WHERE n IN (1, 2);

            DROP TABLE booking_chat_admin_seed;
            """, connection);
        command.Parameters.AddWithValue("count", count);
        command.Parameters.AddWithValue("customerId", customerId);
        command.Parameters.AddWithValue("caregiverProfileId", caregiverProfileId);
        command.Parameters.AddWithValue("caregiverUserId", caregiverUserId);
        command.Parameters.AddWithValue("updatedFrom", updatedFrom);
        await command.ExecuteNonQueryAsync();
    }
}
