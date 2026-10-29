using CareSitter.ApiHost.ChatFirestore;
using CareSitter.Contracts.Services;
using Google.Cloud.Firestore;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;

namespace CareSitter.IntegrationTests;

[AttributeUsage(AttributeTargets.Method)]
internal sealed class ChatFirestoreFactAttribute : FactAttribute
{
    public ChatFirestoreFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(
                PostgresFactAttribute.ConnectionVariable)) ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("FIRESTORE_EMULATOR_HOST")))
            Skip = "Requires a temporary PostgreSQL test database and Firestore emulator.";
    }
}

public sealed class ChatFirestoreProjectionTests(
    PostgresRaceTestDatabaseFixture fixture) : IClassFixture<PostgresRaceTestDatabaseFixture>
{
    [ChatFirestoreFact]
    public async Task Failed_projection_is_dead_lettered_and_can_be_replayed_by_an_active_admin()
    {
        var testDb = fixture.Database!;
        long eventId;
        Guid adminId;
        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var enqueue = new NpgsqlCommand("""
                INSERT INTO public.chat_firestore_outbox(chat_type, action, conversation_id)
                VALUES ('SUPPORT', 'REFRESH', gen_random_uuid()) RETURNING id
                """, connection);
            eventId = (long)(await enqueue.ExecuteScalarAsync())!;
            await using var admin = new NpgsqlCommand("""
                SELECT id FROM identity.users WHERE 'ADMIN' = ANY(roles)
                  AND status = 'ACTIVE' AND admin_is_active = true LIMIT 1
                """, connection);
            adminId = (Guid)(await admin.ExecuteScalarAsync())!;
        }
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:CareSitter"] = testDb.ConnectionString,
                ["Firebase:ServiceAccountPath"] = Path.Combine(Path.GetTempPath(),
                    $"missing-chat-test-{Guid.NewGuid():N}.json")
            }).Build();
        var failingOptions = Options.Create(new ChatFirestoreOptions
        {
            ProjectionEnabled = true, ProjectId = "demo-caresitter-chat", MaxAttempts = 1
        });
        var failingWorker = new ChatFirestoreProjectionWorker(configuration, failingOptions,
            new ChatFirestoreClient(failingOptions, configuration),
            NullLogger<ChatFirestoreProjectionWorker>.Instance);
        var accessGate = new ChatFirestoreAccessGate(configuration);
        Assert.False(await accessGate.CanIssueSessionAsync(CancellationToken.None));
        Assert.Equal(0, await failingWorker.ProcessBatchAsync(CancellationToken.None));
        Assert.False(await accessGate.CanIssueSessionAsync(CancellationToken.None));
        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var state = new NpgsqlCommand("""
                SELECT attempts, dead_letter_at IS NOT NULL, delivered_at IS NULL
                FROM public.chat_firestore_outbox WHERE id = @id
                """, connection);
            state.Parameters.AddWithValue("id", eventId);
            await using var reader = await state.ExecuteReaderAsync();
            Assert.True(await reader.ReadAsync());
            Assert.Equal(1, reader.GetInt32(0));
            Assert.True(reader.GetBoolean(1));
            Assert.True(reader.GetBoolean(2));
        }

        var settings = Options.Create(new ChatFirestoreOptions
        {
            ProjectionEnabled = true, UseEmulator = true, ProjectId = "demo-caresitter-chat"
        });
        var client = new ChatFirestoreClient(settings, configuration);
        var worker = new ChatFirestoreProjectionWorker(configuration, settings, client,
            NullLogger<ChatFirestoreProjectionWorker>.Instance);
        Assert.Equal(0, await worker.ProcessBatchAsync(CancellationToken.None));
        var controller = new ChatFirestoreAdminController(new AdminActor(adminId),
            new AdminLookup(adminId),
            new ChatFirestoreReconciler(configuration, client, settings), configuration, settings);
        Assert.IsType<AcceptedResult>(await controller.ReplayAsync(eventId, CancellationToken.None));
        Assert.Equal(1, await worker.ProcessBatchAsync(CancellationToken.None));
        Assert.True(await accessGate.CanIssueSessionAsync(CancellationToken.None));
    }

    [ChatFirestoreFact]
    public async Task Projects_both_chat_flows_retries_and_purges_booking_content()
    {
        var testDb = fixture.Database!;
        var bookingId = Guid.NewGuid();
        var bookingChatId = Guid.NewGuid();
        var epochId = Guid.NewGuid();
        var bookingMessageId = Guid.NewGuid();
        var ticketId = Guid.NewGuid();
        var supportChatId = Guid.NewGuid();
        var supportMessageId = Guid.NewGuid();
        Guid ownerId, adminId, caregiverProfileId, caregiverUserId;
        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using (var actors = new NpgsqlCommand("""
                SELECT
                  (SELECT id FROM identity.users WHERE 'CUSTOMER' = ANY(roles) LIMIT 1),
                  (SELECT id FROM identity.users WHERE 'ADMIN' = ANY(roles)
                     AND admin_is_active = true LIMIT 1),
                  (SELECT id FROM people.caregiver_profiles LIMIT 1),
                  (SELECT user_id FROM people.caregiver_profiles LIMIT 1)
                """, connection))
            await using (var reader = await actors.ExecuteReaderAsync())
            {
                Assert.True(await reader.ReadAsync());
                ownerId = reader.GetGuid(0);
                adminId = reader.GetGuid(1);
                caregiverProfileId = reader.GetGuid(2);
                caregiverUserId = reader.GetGuid(3);
            }
            await using var insert = new NpgsqlCommand("""
                INSERT INTO support.support_tickets(id, user_id, type, title, description)
                VALUES (@ticket, @owner, 'GENERAL', 'Projection test', 'Projection test');
                INSERT INTO support.chat_conversations
                    (id, ticket_id, owner_user_id, create_key, create_payload_hash,
                     last_sequence, last_message_at, created_at, updated_at)
                VALUES (@support_chat, @ticket, @owner, gen_random_uuid(),
                    repeat('a', 64), 1, now(), now(), now());
                INSERT INTO support.chat_messages
                    (id, conversation_id, sequence, sender_user_id, sender_role,
                     idempotency_key, body, payload_hash, created_at)
                VALUES (@support_message, @support_chat, 1, @owner, 'CUSTOMER',
                    gen_random_uuid(), 'Support test', repeat('b', 64), now());
                UPDATE support.support_tickets SET status = 'IN_PROGRESS',
                    assigned_admin_id = @admin WHERE id = @ticket;

                INSERT INTO booking.bookings
                    (id, customer_id, beneficiary_id, caregiver_id, address_id,
                     service_type_id, scheduled_start, scheduled_end, created_at, updated_at)
                SELECT @booking, @owner,
                    (SELECT id FROM people.beneficiaries LIMIT 1), @caregiver_profile,
                    (SELECT id FROM catalog.addresses LIMIT 1),
                    (SELECT id FROM catalog.service_types LIMIT 1),
                    now() + interval '1 day', now() + interval '2 days', now(), now();
                INSERT INTO booking.booking_chat_conversations
                    (id, booking_id, last_sequence, change_version, scope_version,
                     last_message_at, created_at, updated_at)
                VALUES (@booking_chat, @booking, 1, 1, 1, now(), now(), now());
                INSERT INTO booking.booking_chat_epochs
                    (id, conversation_id, epoch_number, caregiver_profile_id,
                     caregiver_user_id, started_at)
                VALUES (@epoch, @booking_chat, 1, @caregiver_profile,
                    @caregiver_user, now());
                INSERT INTO booking.booking_chat_messages
                    (id, conversation_id, epoch_id, sequence, kind, body_snapshot,
                     source_event_id, created_at)
                VALUES (@booking_message, @booking_chat, @epoch, 1,
                    'system', 'Booking test', gen_random_uuid(), now());
                """, connection);
            insert.Parameters.AddWithValue("ticket", ticketId);
            insert.Parameters.AddWithValue("owner", ownerId);
            insert.Parameters.AddWithValue("support_chat", supportChatId);
            insert.Parameters.AddWithValue("support_message", supportMessageId);
            insert.Parameters.AddWithValue("admin", adminId);
            insert.Parameters.AddWithValue("booking", bookingId);
            insert.Parameters.AddWithValue("caregiver_profile", caregiverProfileId);
            insert.Parameters.AddWithValue("booking_chat", bookingChatId);
            insert.Parameters.AddWithValue("epoch", epochId);
            insert.Parameters.AddWithValue("caregiver_user", caregiverUserId);
            insert.Parameters.AddWithValue("booking_message", bookingMessageId);
            await insert.ExecuteNonQueryAsync();
        }

        var settings = Options.Create(new ChatFirestoreOptions
        {
            ProjectionEnabled = true, UseEmulator = true,
            ProjectId = "demo-caresitter-chat", BatchSize = 50
        });
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(
            new Dictionary<string, string?>
            { ["ConnectionStrings:CareSitter"] = testDb.ConnectionString }).Build();
        var client = new ChatFirestoreClient(settings, configuration);
        var worker = new ChatFirestoreProjectionWorker(configuration, settings,
            client, NullLogger<ChatFirestoreProjectionWorker>.Instance);
        Assert.True(await worker.ProcessBatchAsync(CancellationToken.None) >= 3);
        var db = client.Database;
        var bookingMessage = db.Collection("chatConversations")
            .Document(bookingChatId.ToString()).Collection("epochs")
            .Document(epochId.ToString()).Collection("messages")
            .Document(bookingMessageId.ToString());
        var supportMessage = db.Collection("chatConversations")
            .Document(supportChatId.ToString()).Collection("epochs")
            .Document(supportChatId.ToString()).Collection("messages")
            .Document(supportMessageId.ToString());
        Assert.Equal("Booking test", (await bookingMessage.GetSnapshotAsync()).GetValue<string>("body"));
        Assert.Equal("Support test", (await supportMessage.GetSnapshotAsync()).GetValue<string>("body"));

        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var revokeRole = new NpgsqlCommand("""
                UPDATE identity.users SET roles = ARRAY['CUSTOMER'] WHERE id = @user
                """, connection);
            revokeRole.Parameters.AddWithValue("user", caregiverUserId);
            await revokeRole.ExecuteNonQueryAsync();
        }
        await worker.ProcessBatchAsync(CancellationToken.None);
        Assert.False((await db.Collection("chatUserAccess").Document(caregiverUserId.ToString())
            .GetSnapshotAsync()).GetValue<bool>("activeCaregiver"));

        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var replay = new NpgsqlCommand("""
                UPDATE public.chat_firestore_outbox SET delivered_at = NULL
                WHERE chat_type = 'BOOKING' AND action = 'MESSAGE' AND message_id = @message
                """, connection);
            replay.Parameters.AddWithValue("message", bookingMessageId);
            await replay.ExecuteNonQueryAsync();
        }
        await worker.ProcessBatchAsync(CancellationToken.None);
        var count = await bookingMessage.Parent.GetSnapshotAsync();
        Assert.Single(count.Documents);

        await bookingMessage.SetAsync(new { body = "Drifted content" }, SetOptions.MergeAll);
        await supportMessage.DeleteAsync();
        var reconciler = new ChatFirestoreReconciler(configuration, client, settings);
        var bookingScan = await reconciler.ScanAsync("BOOKING", null, null, 100,
            CancellationToken.None);
        var supportScan = await reconciler.ScanAsync("SUPPORT", null, null, 100,
            CancellationToken.None);
        Assert.Equal(1, bookingScan.Mismatched);
        Assert.Equal(1, supportScan.Missing);
        settings.Value.ReconcileBatchSize = 1;
        var job = new ChatFirestoreReconcileJob(configuration, settings, reconciler,
            NullLogger<ChatFirestoreReconcileJob>.Instance);
        await job.RunAsync(CancellationToken.None);
        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var checkpoints = new NpgsqlCommand("""
                SELECT count(*) FROM public.chat_firestore_reconcile_cursors
                WHERE after_message_id IS NOT NULL
                """, connection);
            Assert.Equal(2L, (long)(await checkpoints.ExecuteScalarAsync())!);
        }
        await job.RunAsync(CancellationToken.None);
        await worker.ProcessBatchAsync(CancellationToken.None);
        Assert.Equal("Booking test", (await bookingMessage.GetSnapshotAsync()).GetValue<string>("body"));
        Assert.Equal("Support test", (await supportMessage.GetSnapshotAsync()).GetValue<string>("body"));

        await using (var connection = await testDb.OpenConnectionAsync())
        {
            await using var purge = new NpgsqlCommand("""
                UPDATE booking.booking_chat_conversations SET purged_at = now() WHERE id = @chat
                """, connection);
            purge.Parameters.AddWithValue("chat", bookingChatId);
            await purge.ExecuteNonQueryAsync();
        }
        await worker.ProcessBatchAsync(CancellationToken.None);
        Assert.False((await bookingMessage.GetSnapshotAsync()).Exists);
        Assert.False((await db.Collection("chatConversations")
            .Document(bookingChatId.ToString()).GetSnapshotAsync()).Exists);
    }
    private sealed class AdminActor(Guid userId) : ICurrentUser
    {
        public Guid? UserId => userId;
        public IReadOnlyCollection<string> Roles => ["ADMIN"];
        public bool IsInRole(string role) => role == "ADMIN";
    }

    private sealed class AdminLookup(Guid userId) : IActiveAdminLookup
    {
        public Task<bool> IsActiveAdminAsync(Guid candidate, CancellationToken ct = default) =>
            Task.FromResult(candidate == userId);
    }
}
