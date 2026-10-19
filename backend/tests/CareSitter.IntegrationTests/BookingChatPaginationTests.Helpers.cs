using System.Data;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Controllers;
using CareSitter.Modules.Booking.Domain;
using CareSitter.Modules.Booking.Infrastructure;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Npgsql;
using Xunit;
using Xunit.Abstractions;

namespace CareSitter.IntegrationTests;

public sealed partial class BookingChatPaginationTests
{
#region Helpers & Seeding

    private BookingChatService CreateChatService(
        BookingDbContext db, Guid userId, string role, Guid caregiverProfileId, Guid caregiverUserId)
    {
        var currentUser = new TestActor(userId, role);
        var people = new TestPeople(caregiverProfileId, caregiverUserId, approved: true);
        return new BookingChatService(db, currentUser, people, _chatOptions, _dataProtection);
    }

    private string CreateSignedCursor(
        Guid conversationId, Guid userId, long scopeVersion, string direction, long position, long upperBound)
    {
        var protector = _dataProtection.CreateProtector("CareSitter.BookingChat.Cursor.v1");
        var payload = new
        {
            ConversationId = conversationId,
            UserId = userId,
            ScopeVersion = scopeVersion,
            Direction = direction,
            Position = position,
            UpperBound = upperBound
        };
        var jsonBytes = JsonSerializer.SerializeToUtf8Bytes(payload);
        return Convert.ToBase64String(protector.Protect(jsonBytes));
    }

    private async Task<SeedData> SeedConversationWithMessagesAsync(
        BookingDbContext db, int messageCount, bool jumbleTimestamps)
    {
        var bookingId = Guid.NewGuid();
        var conversationId = Guid.NewGuid();
        var epochId = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;

        await using var conn = await Database.OpenConnectionAsync();

        // 1. Tạo booking
        await using (var cmd = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, address_id, service_type_id, caregiver_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount, customer_payable_amount)
            SELECT @id, beneficiary.customer_id, beneficiary.id, address.id, service.id, caregiver.id,
                   now() + interval '3 days' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '3 days 2 hours' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '30 minutes', 'CAREGIVER_ACCEPTED', 100000, 15000, 85000, 100000
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) service
            CROSS JOIN LATERAL (SELECT id, user_id FROM people.caregiver_profiles ORDER BY id LIMIT 1) caregiver
            ORDER BY beneficiary.id, address.id LIMIT 1
            RETURNING customer_id, caregiver_id,
                      (SELECT user_id FROM people.caregiver_profiles WHERE id = caregiver_id);
            """, conn))
        {
            cmd.Parameters.AddWithValue("id", bookingId);
            await using var reader = await cmd.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            var customerId = reader.GetGuid(0);
            var caregiverProfileId = reader.GetGuid(1);
            var caregiverUserId = reader.GetGuid(2);
            await reader.CloseAsync();

            // 2. Tạo conversation & epoch
            await using (var convCmd = new NpgsqlCommand("""
                INSERT INTO booking.booking_chat_conversations (
                    id, booking_id, last_sequence, change_version, scope_version, created_at, updated_at)
                VALUES (@convId, @bookingId, @seq, @count, 1, @now, @now);

                INSERT INTO booking.booking_chat_epochs (
                    id, conversation_id, epoch_number, caregiver_profile_id, caregiver_user_id, started_at)
                VALUES (@epochId, @convId, 1, @cgProfileId, @cgUserId, @now);
                """, conn))
            {
                convCmd.Parameters.AddWithValue("convId", conversationId);
                convCmd.Parameters.AddWithValue("bookingId", bookingId);
                convCmd.Parameters.AddWithValue("seq", (long)messageCount);
                convCmd.Parameters.AddWithValue("count", Math.Max(1L, (long)messageCount));
                convCmd.Parameters.AddWithValue("now", now);
                convCmd.Parameters.AddWithValue("epochId", epochId);
                convCmd.Parameters.AddWithValue("cgProfileId", caregiverProfileId);
                convCmd.Parameters.AddWithValue("cgUserId", caregiverUserId);
                await convCmd.ExecuteNonQueryAsync();
            }

            // 3. Bulk insert messages nếu count > 0
            if (messageCount > 0)
            {
                var timestampExpr = jumbleTimestamps
                    // Cố tình làm timestamp không đơn điệu: nhóm 10 tin trùng nhau và đảo ngược thời gian theo chu kỳ
                    ? "@now + (((@count - s) / 10) * interval '1 second')"
                    : "@now + ((s / 10) * interval '1 second')";

                var bulkSql = $"""
                    INSERT INTO booking.booking_chat_messages (
                        id, conversation_id, epoch_id, sequence,
                        sender_user_id, sender_role, kind,
                        body_snapshot, idempotency_key, payload_hash,
                        created_at)
                    SELECT
                        gen_random_uuid(),
                        @convId,
                        @epochId,
                        s,
                        @customerId,
                        'CUSTOMER',
                        'text',
                        'Message ' || s,
                        gen_random_uuid(),
                        repeat(md5(s::text), 2),
                        {timestampExpr}
                    FROM generate_series(1, @count) AS s;
                    """;

                await using var bulkCmd = new NpgsqlCommand(bulkSql, conn);
                bulkCmd.Parameters.AddWithValue("convId", conversationId);
                bulkCmd.Parameters.AddWithValue("epochId", epochId);
                bulkCmd.Parameters.AddWithValue("count", messageCount);
                bulkCmd.Parameters.AddWithValue("customerId", customerId);
                bulkCmd.Parameters.AddWithValue("now", now);
                var inserted = await bulkCmd.ExecuteNonQueryAsync();
                Assert.Equal(messageCount, inserted);
            }

            return new SeedData(bookingId, conversationId, epochId, customerId, caregiverProfileId, caregiverUserId);
        }
    }

    private async Task<TwoEpochSeedData> SeedTwoEpochConversationAsync(
        BookingDbContext db, int epoch1Messages, int epoch2Messages)
    {
        var bookingId = Guid.NewGuid();
        var conversationId = Guid.NewGuid();
        var epoch1Id = Guid.NewGuid();
        var epoch2Id = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;
        var total = epoch1Messages + epoch2Messages;

        await using var conn = await Database.OpenConnectionAsync();

        // 1. Tạo booking với 2 caregiver profile
        await using var cmd = new NpgsqlCommand("""
            SELECT cp.id, cp.user_id
            FROM people.caregiver_profiles cp
            ORDER BY cp.id
            LIMIT 2;
            """, conn);

        await using var reader = await cmd.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        var cg1ProfileId = reader.GetGuid(0);
        var cg1UserId = reader.GetGuid(1);
        Assert.True(await reader.ReadAsync());
        var cg2ProfileId = reader.GetGuid(0);
        var cg2UserId = reader.GetGuid(1);
        await reader.CloseAsync();

        // Tạo booking gán cho Caregiver 2 hiện tại
        await using var bookCmd = new NpgsqlCommand("""
            INSERT INTO booking.bookings (
                id, customer_id, beneficiary_id, address_id, service_type_id, caregiver_id,
                scheduled_start, scheduled_end, payment_deadline, status,
                escrow_amount, platform_fee_amount, caregiver_earning_amount, customer_payable_amount)
            SELECT @id, beneficiary.customer_id, beneficiary.id, address.id, service.id, @cg2ProfileId,
                   now() + interval '3 days' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '3 days 2 hours' + (SELECT count(*) FROM booking.bookings) * interval '3 hours',
                   now() + interval '30 minutes', 'CAREGIVER_ACCEPTED', 100000, 15000, 85000, 100000
            FROM people.beneficiaries beneficiary
            JOIN catalog.addresses address ON address.owner_user_id = beneficiary.customer_id
            CROSS JOIN LATERAL (SELECT id FROM catalog.service_types ORDER BY id LIMIT 1) service
            ORDER BY beneficiary.id, address.id LIMIT 1
            RETURNING customer_id;
            """, conn);
        bookCmd.Parameters.AddWithValue("id", bookingId);
        bookCmd.Parameters.AddWithValue("cg2ProfileId", cg2ProfileId);
        var customerId = (Guid)(await bookCmd.ExecuteScalarAsync())!;

        // 2. Tạo conversation & 2 epochs: Epoch 1 ended, Epoch 2 active
        await using var convCmd = new NpgsqlCommand("""
            INSERT INTO booking.booking_chat_conversations (
                id, booking_id, last_sequence, change_version, scope_version, created_at, updated_at)
            VALUES (@convId, @bookingId, @total, @total, 1, @now, @now);

            INSERT INTO booking.booking_chat_epochs (
                id, conversation_id, epoch_number, caregiver_profile_id, caregiver_user_id, started_at, ended_at)
            VALUES (@epoch1Id, @convId, 1, @cg1ProfileId, @cg1UserId, @now - interval '1 hour', @now - interval '30 minutes');

            INSERT INTO booking.booking_chat_epochs (
                id, conversation_id, epoch_number, caregiver_profile_id, caregiver_user_id, started_at, ended_at)
            VALUES (@epoch2Id, @convId, 2, @cg2ProfileId, @cg2UserId, @now - interval '30 minutes', NULL);
            """, conn);
        convCmd.Parameters.AddWithValue("convId", conversationId);
        convCmd.Parameters.AddWithValue("bookingId", bookingId);
        convCmd.Parameters.AddWithValue("total", (long)total);
        convCmd.Parameters.AddWithValue("now", now);
        convCmd.Parameters.AddWithValue("epoch1Id", epoch1Id);
        convCmd.Parameters.AddWithValue("epoch2Id", epoch2Id);
        convCmd.Parameters.AddWithValue("cg1ProfileId", cg1ProfileId);
        convCmd.Parameters.AddWithValue("cg1UserId", cg1UserId);
        convCmd.Parameters.AddWithValue("cg2ProfileId", cg2ProfileId);
        convCmd.Parameters.AddWithValue("cg2UserId", cg2UserId);
        await convCmd.ExecuteNonQueryAsync();

        // Insert messages Epoch 1 (sequence 1..50)
        await using var msg1Cmd = new NpgsqlCommand("""
            INSERT INTO booking.booking_chat_messages (
                id, conversation_id, epoch_id, sequence,
                sender_user_id, sender_role, kind,
                body_snapshot, idempotency_key, payload_hash, created_at)
            SELECT
                gen_random_uuid(), @convId, @epoch1Id, s, @customerId, 'CUSTOMER', 'text',
                'Epoch 1 Message ' || s, gen_random_uuid(), repeat(md5(s::text), 2),
                @now - interval '50 minutes' + (s * interval '10 seconds')
            FROM generate_series(1, @count1) AS s;
            """, conn);
        msg1Cmd.Parameters.AddWithValue("convId", conversationId);
        msg1Cmd.Parameters.AddWithValue("epoch1Id", epoch1Id);
        msg1Cmd.Parameters.AddWithValue("customerId", customerId);
        msg1Cmd.Parameters.AddWithValue("count1", epoch1Messages);
        msg1Cmd.Parameters.AddWithValue("now", now);
        await msg1Cmd.ExecuteNonQueryAsync();

        // Insert messages Epoch 2 (sequence 51..250)
        await using var msg2Cmd = new NpgsqlCommand("""
            INSERT INTO booking.booking_chat_messages (
                id, conversation_id, epoch_id, sequence,
                sender_user_id, sender_role, kind,
                body_snapshot, idempotency_key, payload_hash, created_at)
            SELECT
                gen_random_uuid(), @convId, @epoch2Id, s, @customerId, 'CUSTOMER', 'text',
                'Epoch 2 Message ' || s, gen_random_uuid(), repeat(md5(s::text), 2),
                @now - interval '25 minutes' + ((s - @count1) * interval '5 seconds')
            FROM generate_series(@count1 + 1, @total) AS s;
            """, conn);
        msg2Cmd.Parameters.AddWithValue("convId", conversationId);
        msg2Cmd.Parameters.AddWithValue("epoch2Id", epoch2Id);
        msg2Cmd.Parameters.AddWithValue("customerId", customerId);
        msg2Cmd.Parameters.AddWithValue("count1", epoch1Messages);
        msg2Cmd.Parameters.AddWithValue("total", total);
        msg2Cmd.Parameters.AddWithValue("now", now);
        await msg2Cmd.ExecuteNonQueryAsync();

        return new TwoEpochSeedData(bookingId, conversationId, epoch1Id, epoch2Id, customerId,
            cg1ProfileId, cg1UserId, cg2ProfileId, cg2UserId);
    }

    private async Task InsertRawMessageAsync(
        BookingDbContext db, Guid conversationId, Guid epochId, long sequence, Guid senderUserId)
    {
        await using var conn = await Database.OpenConnectionAsync();
        await using var cmd = new NpgsqlCommand("""
            INSERT INTO booking.booking_chat_messages (
                id, conversation_id, epoch_id, sequence,
                sender_user_id, sender_role, kind,
                body_snapshot, idempotency_key, payload_hash, created_at)
            VALUES (
                gen_random_uuid(), @convId, @epochId, @seq, @userId, 'CUSTOMER', 'text',
                'Extra Message ' || @seq, gen_random_uuid(), repeat(md5(@seq::text), 2), now());

            UPDATE booking.booking_chat_conversations
            SET last_sequence = GREATEST(last_sequence, @seq),
                change_version = change_version + 1,
                updated_at = now()
            WHERE id = @convId;
            """, conn);
        cmd.Parameters.AddWithValue("convId", conversationId);
        cmd.Parameters.AddWithValue("epochId", epochId);
        cmd.Parameters.AddWithValue("seq", sequence);
        cmd.Parameters.AddWithValue("userId", senderUserId);
        await cmd.ExecuteNonQueryAsync();
    }

    private sealed record SeedData(
        Guid BookingId, Guid ConversationId, Guid EpochId, Guid CustomerId,
        Guid CaregiverProfileId, Guid CaregiverUserId);

    private sealed record TwoEpochSeedData(
        Guid BookingId, Guid ConversationId, Guid Epoch1Id, Guid Epoch2Id, Guid CustomerId,
        Guid Caregiver1ProfileId, Guid Caregiver1UserId, Guid Caregiver2ProfileId, Guid Caregiver2UserId);

    private sealed class TestActor(Guid id, params string[] roles) : ICurrentUser
    {
        public Guid? UserId => id;
        public IReadOnlyCollection<string> Roles => roles;
        public bool IsInRole(string role) => roles.Contains(role);
    }

    private sealed class TestPeople(Guid profileId, Guid userId, bool approved) : IPeopleLookupService
    {
        public Task<bool> BeneficiaryBelongsToAsync(Guid beneficiaryId, Guid customerId, CancellationToken ct = default) => Task.FromResult(false);
        public Task<bool> CaregiverIsAvailableAsync(Guid caregiverId, DateTimeOffset start, DateTimeOffset end, CancellationToken ct = default) => Task.FromResult(approved);
        public Task<bool> IsCaregiverApprovedAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult(approved && caregiverId == profileId);
        public Task<bool> IsCaregiverForBookingAsync(Guid caregiverId, Guid actorId, CancellationToken ct = default) => Task.FromResult(caregiverId == profileId && actorId == userId);
        public Task<Guid?> GetCaregiverProfileIdByUserIdAsync(Guid actorId, CancellationToken ct = default) => Task.FromResult<Guid?>(actorId == userId ? profileId : null);
        public Task<Guid?> GetUserIdByCaregiverProfileIdAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult<Guid?>(userId);
        public Task<PeopleDisplaySummary?> GetBeneficiaryDisplayAsync(Guid beneficiaryId, CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
        public Task<PeopleDisplaySummary?> GetCaregiverDisplayAsync(Guid caregiverId, CancellationToken ct = default) => Task.FromResult<PeopleDisplaySummary?>(null);
    }

    #endregion
}
