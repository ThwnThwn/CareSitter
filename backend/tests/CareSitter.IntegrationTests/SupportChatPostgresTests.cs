using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Security.Claims;
using System.Text;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Infrastructure.Hubs;
using CareSitter.Modules.Support.Application.Chat;
using CareSitter.Modules.Support.Controllers;
using CareSitter.Modules.Support.Infrastructure;
using CareSitter.Modules.Support.Domain;
using CareSitter.SharedKernel.Results;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Kafka.Configuration;
using CareSitter.Messaging.Kafka.Serialization;
using CareSitter.Messaging.Persistence.Outbox;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class SupportChatPostgresTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;
    private readonly Guid _owner = Guid.NewGuid();
    private readonly Guid _other = Guid.NewGuid();
    private readonly Guid _caregiver = Guid.NewGuid();
    private readonly Guid _admin = Guid.NewGuid();
    private readonly Guid _secondAdmin = Guid.NewGuid();

    public async Task InitializeAsync()
    {
        _database = await PostgresRaceTestDatabase.CreateAsync();
        await using var connection = await _database.OpenConnectionAsync();
        foreach (var (id, role) in new[]
                 { (_owner, "CUSTOMER"), (_other, "CUSTOMER"),
                   (_caregiver, "CAREGIVER"),
                   (_admin, "ADMIN"), (_secondAdmin, "ADMIN") })
        {
            await using var command = new NpgsqlCommand(
                "INSERT INTO identity.users(id, email, roles, admin_is_active) VALUES (@id, @email, ARRAY[@role]::varchar[], @active)",
                connection);
            command.Parameters.AddWithValue("id", id);
            command.Parameters.AddWithValue("email", $"{id:N}@example.test");
            command.Parameters.AddWithValue("role", role);
            command.Parameters.AddWithValue("active", role == "ADMIN");
            await command.ExecuteNonQueryAsync();
        }
    }

    public async Task DisposeAsync()
    {
        if (_database is not null) await _database.DisposeAsync();
    }

    private SupportDbContext Context() => new(new DbContextOptionsBuilder<SupportDbContext>()
        .UseNpgsql(_database.ConnectionString).Options);

    private static IHubContext<SupportChatHub> Hub()
    {
        var provider = new ServiceCollection().AddLogging().AddSignalR().Services.BuildServiceProvider();
        return provider.GetRequiredService<IHubContext<SupportChatHub>>();
    }

    private SupportChatService Chat(SupportDbContext db, bool push = false,
        bool allowPush = true, bool misconfiguredPush = false)
    {
        var registry = new EventTypeRegistry();
        var kafka = new KafkaOptions();
        registry.Add<NotificationRequested>("caresitter.notifications.requested", 1,
            kafka.NotificationsTopic);
        var serializer = new JsonEventSerializer(registry, kafka);
        return new(db, new BookingAccess(),
        new AdminLookup(_admin, _secondAdmin), new RecipientReader(allowPush),
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["SupportChat:Enabled"] = "true",
            ["SupportChat:PushEnabled"] = push.ToString()
        }).Build(), Hub(), NullLogger<SupportChatService>.Instance,
        new MessagingSettings(push && !misconfiguredPush, push && !misconfiguredPush,
            false, false, "test"), serializer,
        new OutboxWriter<SupportDbContext>(db, serializer));
    }

    [PostgresFact]
    public async Task Create_claim_reply_read_close_and_retry_preserve_one_history()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var admin = new ChatActor(_admin, true, "ADMIN");
        var createKey = Guid.NewGuid();
        var request = new ChatCreateRequest("Cần hỗ trợ đặt lịch", "Tôi cần hỏi về lịch đặt ngày mai.", null);
        Guid conversationId;
        await using (var db = Context())
        {
            var chat = Chat(db);
            var created = await chat.CreateAsync(owner, createKey, request, default);
            Assert.True(created.IsSuccess, created.IsFailure ? created.Error.Message : "");
            conversationId = created.Value.Conversation.Id;
            Assert.Equal(1, created.Value.FirstMessage.Sequence);
            var replay = await chat.CreateAsync(owner, createKey, request, default);
            Assert.True(replay.IsSuccess);
            Assert.True(replay.Value.Replayed);
            Assert.Equal(created.Value.FirstMessage.Id, replay.Value.FirstMessage.Id);
            Assert.Equal("support.chat.idempotency_conflict",
                (await chat.CreateAsync(owner, createKey,
                    request with { FirstMessage = "Nội dung khác đủ dài." }, default)).Error.Code);
            Assert.Equal("support.chat.not_found",
                (await chat.GetAsync(new ChatActor(_other, false, "CUSTOMER"),
                    conversationId, default)).Error.Code);
        }
        await using (var db = Context())
        {
            var chat = Chat(db);
            var claim = await chat.ClaimAsync(admin, conversationId, 1, default);
            Assert.True(claim.IsSuccess);
            Assert.Equal("IN_PROGRESS", claim.Value.Status);
            var key = Guid.NewGuid();
            var reply = await chat.SendAsync(admin, conversationId, key, "CareSitter đã nhận yêu cầu.", default);
            Assert.True(reply.IsSuccess);
            Assert.Equal(2, reply.Value.Sequence);
            Assert.Equal(reply.Value.Id,
                (await chat.SendAsync(admin, conversationId, key,
                    "CareSitter đã nhận yêu cầu.", default)).Value.Id);
            Assert.Single(await db.Notifications.Where(x => x.ChatMessageId == reply.Value.Id).ToListAsync());
            var read = await chat.ReadAsync(owner, conversationId, 2, default);
            Assert.Equal(0, read.Value.UnreadCount);
            var close = await chat.StatusAsync(admin, conversationId, "CLOSED", 2,
                "Đã trả lời và kết thúc.", default);
            Assert.True(close.IsSuccess);
            Assert.Equal("CLOSED", close.Value.Status);
            Assert.Equal("support.chat.closed",
                (await chat.SendAsync(owner, conversationId, Guid.NewGuid(),
                    "Tôi còn một câu hỏi", default)).Error.Code);
            var oldReply = await chat.SendAsync(admin, conversationId, key,
                "CareSitter đã nhận yêu cầu.", default);
            Assert.True(oldReply.IsSuccess);
            Assert.True(oldReply.Value.Replayed);
            Assert.Equal(2, await db.ChatMessages.CountAsync(x => x.ConversationId == conversationId));
        }
        await using (var db = Context())
        {
            var chat = Chat(db);
            var next = await chat.CreateAsync(owner, Guid.NewGuid(),
                new ChatCreateRequest("Yêu cầu tiếp theo", "Tôi cần hỗ trợ cho lịch khác.", null), default);
            Assert.True(next.IsSuccess);
            var firstPage = await chat.ListAsync(owner, null, null, null, 1, default);
            Assert.True(firstPage.Value.HasMore);
            Assert.Equal(next.Value.Conversation.Id, firstPage.Value.Items[0].Id);
            var secondPage = await chat.ListAsync(owner, null, firstPage.Value.NextCreatedAt,
                firstPage.Value.NextId, 1, default);
            Assert.Equal(conversationId, Assert.Single(secondPage.Value.Items).Id);
        }
    }

    [PostgresFact]
    public async Task Concurrent_create_claim_and_retry_commit_only_once()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var admin = new ChatActor(_admin, true, "ADMIN");
        var request = new ChatCreateRequest("Hỏi về ca chăm sóc", "Xin hỗ trợ thông tin ca chăm sóc.", null);
        async Task<Result<ChatCreateResponse>> Create(Guid key)
        {
            await using var db = Context();
            return await Chat(db).CreateAsync(owner, key, request, default);
        }
        var createResults = await Task.WhenAll(Create(Guid.NewGuid()), Create(Guid.NewGuid()));
        Assert.Single(createResults, x => x.IsSuccess);
        Assert.Single(createResults, x => x.IsFailure &&
            x.Error.Code == "support.chat.open_conversation_exists");
        var id = createResults.Single(x => x.IsSuccess).Value.Conversation.Id;

        async Task<Result<ChatConversationResponse>> Claim()
        {
            await using var db = Context();
            return await Chat(db).ClaimAsync(admin, id, 1, default);
        }
        var claims = await Task.WhenAll(Claim(), Claim());
        Assert.Single(claims, x => x.IsSuccess);
        Assert.Single(claims, x => x.IsFailure && x.Error.Code == "support.chat.version_conflict");

        var key = Guid.NewGuid();
        async Task<Result<ChatMessageResponse>> Send()
        {
            await using var db = Context();
            return await Chat(db).SendAsync(owner, id, key, "Tôi gửi lại cùng yêu cầu.", default);
        }
        var sends = await Task.WhenAll(Send(), Send());
        Assert.All(sends, x => Assert.True(x.IsSuccess));
        Assert.Equal(sends[0].Value.Id, sends[1].Value.Id);
        Assert.Contains(sends, x => x.Value.Replayed);
        await using var check = Context();
        Assert.Equal(2, await check.ChatMessages.CountAsync(x => x.ConversationId == id));
    }

    [PostgresFact]
    public async Task Admin_reply_commits_inbox_delivery_and_outbox_without_chat_body()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var admin = new ChatActor(_admin, true, "ADMIN");
        await using var db = Context();
        var chat = Chat(db, push: true);
        var created = await chat.CreateAsync(owner, Guid.NewGuid(),
            new ChatCreateRequest("Cần hỗ trợ ứng dụng", "Tôi muốn hỏi về việc đặt lịch.", null), default);
        Assert.True(created.IsSuccess);
        var id = created.Value.Conversation.Id;
        Assert.True((await chat.ClaimAsync(admin, id, 1, default)).IsSuccess);
        var reply = await chat.SendAsync(admin, id, Guid.NewGuid(), "Nội dung trao đổi riêng tư", default);
        Assert.True(reply.IsSuccess);
        var notification = Assert.Single(await db.Notifications.Where(x =>
            x.ChatMessageId == reply.Value.Id).ToListAsync());
        var delivery = Assert.Single(await db.Set<NotificationDelivery>().Where(x =>
            x.NotificationId == notification.Id).ToListAsync());
        var outbox = Assert.Single(await db.Set<KafkaOutboxMessage>().Where(x =>
            x.Id == delivery.EventId).ToListAsync());
        Assert.DoesNotContain(reply.Value.Body, outbox.Envelope);
        Assert.Contains(notification.Id.ToString(), outbox.Envelope);
        Assert.Equal("push", delivery.Channel);

        var muted = await Chat(db, push: true, allowPush: false).SendAsync(admin, id,
            Guid.NewGuid(), "Phản hồi tiếp theo", default);
        Assert.True(muted.IsSuccess);
        var mutedInbox = Assert.Single(await db.Notifications.Where(x =>
            x.ChatMessageId == muted.Value.Id).ToListAsync());
        Assert.Empty(await db.Set<NotificationDelivery>().Where(x =>
            x.NotificationId == mutedInbox.Id).ToListAsync());
    }

    [PostgresFact]
    public async Task Transfer_takeover_and_read_receipt_respect_current_assignment()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var first = new ChatActor(_admin, true, "ADMIN");
        var second = new ChatActor(_secondAdmin, true, "ADMIN");
        await using var db = Context();
        var chat = Chat(db);
        var created = await chat.CreateAsync(owner, Guid.NewGuid(),
            new ChatCreateRequest("Cần hỗ trợ lịch", "Tôi cần đổi lịch cho người thân.", null), default);
        Assert.True(created.IsSuccess);
        var id = created.Value.Conversation.Id;
        Assert.Equal("support.chat.not_assigned", (await chat.ReadAsync(first, id, 1, default)).Error.Code);
        Assert.Equal(0, (await chat.GetAsync(owner, id, default)).Value.StaffLastReadSequence);

        var claimed = await chat.ClaimAsync(first, id, 1, default);
        Assert.True(claimed.IsSuccess);
        Assert.True((await chat.ReadAsync(first, id, 1, default)).IsSuccess);
        Assert.Equal(1, (await chat.GetAsync(owner, id, default)).Value.StaffLastReadSequence);
        var transferred = await chat.TransferAsync(first, id, _secondAdmin, false,
            claimed.Value.TicketVersion, "Chuyển ca trực", default);
        Assert.True(transferred.IsSuccess);
        Assert.Equal("support.chat.not_assigned", (await chat.ReadAsync(first, id, 1, default)).Error.Code);
        Assert.Equal("support.chat.not_assigned", (await chat.SendAsync(first, id,
            Guid.NewGuid(), "Tôi không còn phụ trách.", default)).Error.Code);
        Assert.True((await chat.SendAsync(second, id, Guid.NewGuid(), "Tôi đã nhận ca hỗ trợ.", default)).IsSuccess);
        var taken = await chat.TransferAsync(first, id, _admin, true,
            transferred.Value.TicketVersion, "Nhận lại ca trực", default);
        Assert.True(taken.IsSuccess);
        Assert.Equal(_admin, taken.Value.AssignedAdminId);
        Assert.Equal("support.chat.version_conflict", (await chat.TransferAsync(second, id,
            _secondAdmin, true, transferred.Value.TicketVersion, "Phiên cũ", default)).Error.Code);
        Assert.Equal("support.chat.not_found", (await chat.MessagesAsync(
            new ChatActor(_other, false, "CUSTOMER"), id, null, null, null, 50, default)).Error.Code);
    }

    [PostgresFact]
    public async Task Dropped_realtime_events_recover_all_125_messages_by_cursor()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        await using var db = Context();
        var chat = Chat(db);
        var created = await chat.CreateAsync(owner, Guid.NewGuid(),
            new ChatCreateRequest("Hỏi về dịch vụ", "Tôi cần được giải thích dịch vụ.", null), default);
        Assert.True(created.IsSuccess);
        var id = created.Value.Conversation.Id;
        for (var i = 0; i < 124; i++)
            Assert.True((await chat.SendAsync(owner, id, Guid.NewGuid(), $"Tin nhắn {i}", default)).IsSuccess);

        var observed = new List<long>();
        long after = 0;
        long? highWatermark = null;
        do
        {
            var result = await chat.MessagesAsync(owner, id, null, after, highWatermark, 37, default);
            Assert.True(result.IsSuccess);
            var page = result.Value;
            highWatermark ??= page.HighWatermarkSequence;
            observed.AddRange(page.Items.Select(x => x.Sequence));
            after = page.NextAfterSequence ?? after;
            if (!page.HasMore) break;
        } while (true);
        Assert.Equal(Enumerable.Range(1, 125).Select(x => (long)x), observed);
        Assert.Equal(125, highWatermark);
        Assert.Equal(125, (await chat.ReadAsync(owner, id, 125, default)).Value.OwnLastReadSequence);
    }

    [PostgresFact]
    public async Task Send_close_and_transfer_races_commit_in_ticket_lock_order()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var admin = new ChatActor(_admin, true, "ADMIN");
        Guid firstId;
        await using (var db = Context())
        {
            var chat = Chat(db);
            firstId = (await chat.CreateAsync(owner, Guid.NewGuid(),
                new ChatCreateRequest("Hỗ trợ thanh toán", "Tôi cần hỏi về thanh toán.", null),
                default)).Value.Conversation.Id;
            Assert.True((await chat.ClaimAsync(admin, firstId, 1, default)).IsSuccess);
        }
        async Task<Result<ChatMessageResponse>> Send(Guid id, Guid actorId, string role)
        {
            await using var db = Context();
            return await Chat(db).SendAsync(new ChatActor(actorId, role == "ADMIN", role),
                id, Guid.NewGuid(), "Tin nhắn đang cạnh tranh khóa.", default);
        }
        async Task<Result<ChatConversationResponse>> Close(Guid id)
        {
            await using var db = Context();
            return await Chat(db).StatusAsync(admin, id, "CLOSED", 2,
                "Đã hoàn tất hỗ trợ", default);
        }
        var send = Send(firstId, _owner, "CUSTOMER");
        var close = Close(firstId);
        await Task.WhenAll(send, close);
        Assert.True(close.Result.IsSuccess);
        Assert.True(send.Result.IsSuccess || send.Result.Error.Code == "support.chat.closed");
        await using (var db = Context())
        {
            Assert.Equal(send.Result.IsSuccess ? 2 : 1,
                await db.ChatMessages.CountAsync(x => x.ConversationId == firstId));
            Assert.Equal("CLOSED", (await Chat(db).GetAsync(owner, firstId, default)).Value.Status);
            Assert.Equal("support.chat.closed", (await Chat(db).SendAsync(owner, firstId,
                Guid.NewGuid(), "Không được gửi sau khi đóng", default)).Error.Code);
        }

        // Closing the first conversation frees the unique open-owner slot.
        Guid secondId;
        await using (var db = Context())
        {
            var chat = Chat(db);
            secondId = (await chat.CreateAsync(owner, Guid.NewGuid(),
                new ChatCreateRequest("Hỗ trợ ca mới", "Tôi cần hỗ trợ ca mới.", null),
                default)).Value.Conversation.Id;
            Assert.True((await chat.ClaimAsync(admin, secondId, 1, default)).IsSuccess);
        }
        async Task<Result<ChatConversationResponse>> Transfer()
        {
            await using var db = Context();
            return await Chat(db).TransferAsync(admin, secondId, _secondAdmin, false, 2,
                "Chuyển xử lý cho ca trực sau", default);
        }
        var oldAdminSend = Send(secondId, _admin, "ADMIN");
        var transfer = Transfer();
        await Task.WhenAll(oldAdminSend, transfer);
        Assert.True(transfer.Result.IsSuccess);
        Assert.True(oldAdminSend.Result.IsSuccess ||
            oldAdminSend.Result.Error.Code == "support.chat.not_assigned");
        await using var check = Context();
        Assert.Equal(oldAdminSend.Result.IsSuccess ? 2 : 1,
            await check.ChatMessages.CountAsync(x => x.ConversationId == secondId));
        Assert.Equal(_secondAdmin,
            (await Chat(check).GetAsync(owner, secondId, default)).Value.AssignedAdminId);
    }

    [PostgresFact]
    public async Task Failed_push_precondition_rolls_back_message_and_inbox()
    {
        var owner = new ChatActor(_owner, false, "CUSTOMER");
        var admin = new ChatActor(_admin, true, "ADMIN");
        await using var db = Context();
        var chat = Chat(db);
        var created = await chat.CreateAsync(owner, Guid.NewGuid(),
            new ChatCreateRequest("Cần hỗ trợ tài khoản", "Tài khoản của tôi gặp sự cố.", null), default);
        Assert.True(created.IsSuccess);
        var id = created.Value.Conversation.Id;
        Assert.True((await chat.ClaimAsync(admin, id, 1, default)).IsSuccess);
        // The service must not commit a reply if its required push outbox is unavailable.
        await Assert.ThrowsAsync<InvalidOperationException>(() => Chat(db,
                push: true, misconfiguredPush: true)
            .SendAsync(admin, id, Guid.NewGuid(), "Phản hồi chưa được commit", default));
        await using var check = Context();
        Assert.Equal(1, await check.ChatMessages.CountAsync(x => x.ConversationId == id));
        Assert.Empty(await check.Notifications.Where(x => x.ChatMessageId != null).ToListAsync());
    }

    [PostgresFact]
    public async Task Http_and_signalr_enforce_role_membership_assignment_and_revoked_session()
    {
        var sessions = new TestSessions();
        var ownerSession = sessions.Grant(_owner);
        var otherSession = sessions.Grant(_other);
        var caregiverSession = sessions.Grant(_caregiver);
        var adminSession = sessions.Grant(_admin);
        var secondAdminSession = sessions.Grant(_secondAdmin);
        await using var app = await ServerAsync(sessions);
        var client = app.GetTestClient();
        var ownerToken = Token(_owner, "CUSTOMER", ownerSession);
        var otherToken = Token(_other, "CUSTOMER", otherSession);
        var caregiverToken = Token(_caregiver, "CAREGIVER", caregiverSession);
        var adminToken = Token(_admin, "ADMIN", adminSession);
        var secondAdminToken = Token(_secondAdmin, "ADMIN", secondAdminSession);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", ownerToken);
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/support/conversations")
        { Content = JsonContent.Create(new { subject = "Hỏi về lịch", firstMessage = "Tôi cần hỗ trợ đặt lịch ngày mai." }) };
        request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        var created = await client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var body = await created.Content.ReadFromJsonAsync<ChatCreateResponse>();
        var id = body!.Conversation.Id;
        client.DefaultRequestHeaders.Authorization = null;
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.GetAsync($"/api/v1/support/conversations/{id}?access_token={Uri.EscapeDataString(ownerToken)}")).StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", caregiverToken);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/v1/support/conversations/{id}")).StatusCode);
        var caregiverCreate = new HttpRequestMessage(HttpMethod.Post, "/api/v1/support/conversations")
        { Content = JsonContent.Create(new { subject = "Hỏi về ca", firstMessage = "Tôi cần hỗ trợ ca chăm sóc." }) };
        caregiverCreate.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.Created, (await client.SendAsync(caregiverCreate)).StatusCode);

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", otherToken);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/v1/support/conversations/{id}")).StatusCode);
        var wsClient = app.GetTestServer().CreateWebSocketClient();
        wsClient.ConfigureRequest = message => message.Headers.Authorization = "Bearer " + otherToken;
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        using (var otherSocket = await wsClient.ConnectAsync(new Uri("ws://localhost/hubs/support-chat"), timeout.Token))
        {
            await HandshakeAsync(otherSocket, timeout.Token);
            Assert.Contains("\"result\":\"unauthorized\"",
                await InvokeJoinAsync(otherSocket, id, timeout.Token));
        }

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);
        var claim = await client.PostAsJsonAsync($"/api/v1/admin/support/conversations/{id}/claim",
            new { expectedVersion = 1 });
        Assert.Equal(HttpStatusCode.OK, claim.StatusCode);
        wsClient.ConfigureRequest = _ => { };
        using (var ownerSocket = await wsClient.ConnectAsync(new Uri(
            "ws://localhost/hubs/support-chat?access_token=" + Uri.EscapeDataString(ownerToken)), timeout.Token))
        {
            await HandshakeAsync(ownerSocket, timeout.Token);
            Assert.Contains("\"result\":\"ok\"",
                await InvokeJoinAsync(ownerSocket, id, timeout.Token));
            var reply = new HttpRequestMessage(HttpMethod.Post,
                $"/api/v1/support/conversations/{id}/messages")
            { Content = JsonContent.Create(new { body = "CareSitter đã tiếp nhận yêu cầu." }) };
            reply.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
            Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(reply)).StatusCode);
            Assert.Contains("\"target\":\"MessageCreated\"",
                await ReceiveEventAsync(ownerSocket, "MessageCreated", timeout.Token));
        }
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", ownerToken);
        var missed = await client.GetFromJsonAsync<ChatPageResponse<ChatMessageResponse>>(
            $"/api/v1/support/conversations/{id}/messages?afterSequence=1");
        Assert.Equal(2, Assert.Single(missed!.Items).Sequence);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);
        wsClient.ConfigureRequest = message => message.Headers.Authorization = "Bearer " + adminToken;
        using (var adminSocket = await wsClient.ConnectAsync(new Uri("ws://localhost/hubs/support-chat"), timeout.Token))
        {
            await HandshakeAsync(adminSocket, timeout.Token);
            Assert.Contains("\"result\":\"ok\"",
                await InvokeJoinAsync(adminSocket, id, timeout.Token));
        }
        var transfer = await client.PatchAsJsonAsync(
            $"/api/v1/admin/support/conversations/{id}/assignment",
            new { targetAdminId = _secondAdmin, takeover = false,
                expectedVersion = 2, reason = "Chuyển ca trực" });
        Assert.Equal(HttpStatusCode.OK, transfer.StatusCode);
        var staleSend = new HttpRequestMessage(HttpMethod.Post,
            $"/api/v1/support/conversations/{id}/messages")
        { Content = JsonContent.Create(new { body = "Tôi không còn phụ trách." }) };
        staleSend.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.Conflict, (await client.SendAsync(staleSend)).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", secondAdminToken);
        var secondReply = new HttpRequestMessage(HttpMethod.Post,
            $"/api/v1/support/conversations/{id}/messages")
        { Content = JsonContent.Create(new { body = "Tôi đã nhận ca hỗ trợ." }) };
        secondReply.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.OK, (await client.SendAsync(secondReply)).StatusCode);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminToken);
        var takeover = await client.PatchAsJsonAsync(
            $"/api/v1/admin/support/conversations/{id}/assignment",
            new { targetAdminId = _admin, takeover = true,
                expectedVersion = 3, reason = "Tiếp quản sau bàn giao" });
        Assert.Equal(HttpStatusCode.OK, takeover.StatusCode);
        sessions.Revoke(adminSession);
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await client.GetAsync($"/api/v1/support/conversations/{id}")).StatusCode);
        await Assert.ThrowsAnyAsync<Exception>(async () =>
        {
            using var socket = await wsClient.ConnectAsync(new Uri("ws://localhost/hubs/support-chat"), timeout.Token);
            await HandshakeAsync(socket, timeout.Token);
        });
    }

    private static readonly JwtSettings TestJwt = new()
    {
        Issuer = "Support.Chat.Tests", Audience = "Support.Client",
        SecretKey = "test-support-chat-secret-more-than-32-characters"
    };

    private static string Token(Guid userId, string role, Guid sessionId) =>
        new JwtTokenService(Options.Create(TestJwt))
            .GenerateAccessToken(userId, [role], sessionId: sessionId);

    private async Task<WebApplication> ServerAsync(TestSessions sessions)
    {
        var builder = WebApplication.CreateBuilder();
        builder.WebHost.UseTestServer();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Issuer"] = TestJwt.Issuer, ["Jwt:Audience"] = TestJwt.Audience,
            ["Jwt:SecretKey"] = TestJwt.SecretKey,
            ["SupportChat:Enabled"] = "true", ["SupportChat:PushEnabled"] = "false"
        });
        builder.Services.AddDbContext<SupportDbContext>(x => x.UseNpgsql(_database.ConnectionString));
        builder.Services.AddSingleton<IAccessSessionValidator>(sessions);
        builder.Services.AddSingleton<IActiveAdminLookup>(new AdminLookup(_admin, _secondAdmin));
        builder.Services.AddScoped<IBookingPartyAccess, BookingAccess>();
        builder.Services.AddScoped<INotificationRecipientReader>(_ => new RecipientReader(false));
        builder.Services.AddScoped<ISupportChatMembership, SupportChatMembership>();
        builder.Services.AddScoped<ISupportChatService>(sp => new SupportChatService(
            sp.GetRequiredService<SupportDbContext>(), sp.GetRequiredService<IBookingPartyAccess>(),
            sp.GetRequiredService<IActiveAdminLookup>(),
            sp.GetRequiredService<INotificationRecipientReader>(), builder.Configuration,
            sp.GetRequiredService<IHubContext<SupportChatHub>>(),
            NullLogger<SupportChatService>.Instance));
        builder.Services.AddHttpContextAccessor();
        builder.Services.AddScoped<ICurrentUser, HttpActor>();
        builder.Services.AddDistributedMemoryCache();
        builder.Services.AddJwtAuthentication(builder.Configuration);
        builder.Services.AddSignalR();
        builder.Services.AddSingleton<RealtimeSessionRegistry>();
        builder.Services.AddRateLimiter(options => options.AddPolicy("support-chat-write", _ =>
            RateLimitPartition.GetNoLimiter("test")));
        builder.Services.AddControllers().AddApplicationPart(typeof(SupportChatController).Assembly);
        var app = builder.Build();
        app.UseAuthentication(); app.UseAuthorization(); app.UseRateLimiter();
        app.MapControllers();
        app.MapHub<SupportChatHub>("/hubs/support-chat");
        await app.StartAsync();
        return app;
    }

    private static async Task HandshakeAsync(WebSocket socket, CancellationToken ct)
    {
        await socket.SendAsync(Encoding.UTF8.GetBytes("{\"protocol\":\"json\",\"version\":1}\u001e"),
            WebSocketMessageType.Text, true, ct);
        var buffer = new byte[1024];
        var result = await socket.ReceiveAsync(buffer, ct);
        Assert.Contains("{}", Encoding.UTF8.GetString(buffer, 0, result.Count));
    }

    private static async Task<string> InvokeJoinAsync(WebSocket socket, Guid id, CancellationToken ct)
    {
        var payload = $"{{\"type\":1,\"target\":\"JoinConversation\",\"arguments\":[\"{id}\"],\"invocationId\":\"1\"}}\u001e";
        await socket.SendAsync(Encoding.UTF8.GetBytes(payload), WebSocketMessageType.Text, true, ct);
        var buffer = new byte[2048];
        for (var i = 0; i < 5; i++)
        {
            var result = await socket.ReceiveAsync(buffer, ct);
            var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
            if (message.Contains("\"invocationId\":\"1\"")) return message;
        }
        throw new InvalidOperationException("SignalR did not complete JoinConversation.");
    }

    private static async Task<string> ReceiveEventAsync(WebSocket socket, string target, CancellationToken ct)
    {
        var buffer = new byte[2048];
        for (var i = 0; i < 8; i++)
        {
            var result = await socket.ReceiveAsync(buffer, ct);
            var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
            if (message.Contains($"\"target\":\"{target}\"")) return message;
        }
        throw new InvalidOperationException($"SignalR did not deliver {target}.");
    }

    private sealed class TestSessions : IAccessSessionValidator
    {
        private readonly Dictionary<Guid, Guid> _active = new();
        public Guid Grant(Guid userId) { var id = Guid.NewGuid(); _active[id] = userId; return id; }
        public void Revoke(Guid sessionId) => _active.Remove(sessionId);
        public Task<bool> IsActiveAsync(Guid userId, Guid sessionId, CancellationToken ct = default) =>
            Task.FromResult(_active.TryGetValue(sessionId, out var owner) && owner == userId);
    }

    private sealed class HttpActor(IHttpContextAccessor accessor) : ICurrentUser
    {
        public Guid? UserId => Guid.TryParse(accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier),
            out var id) ? id : null;
        public IReadOnlyCollection<string> Roles => accessor.HttpContext?.User.FindAll(ClaimTypes.Role)
            .Select(x => x.Value).ToArray() ?? [];
        public bool IsInRole(string role) => Roles.Contains(role);
    }

    private sealed class BookingAccess : IBookingPartyAccess
    {
        public Task<bool> IsPartyAsync(Guid bookingId, Guid userId, CancellationToken ct = default) =>
            Task.FromResult(false);
    }

    private sealed class AdminLookup(Guid adminId, Guid secondAdminId) : IActiveAdminLookup
    {
        public Task<bool> IsActiveAdminAsync(Guid userId, CancellationToken ct = default) =>
            Task.FromResult(userId == adminId || userId == secondAdminId);
    }

    private sealed class RecipientReader(bool allowPush) : INotificationRecipientReader
    {
        public Task<NotificationRecipient> GetAsync(Guid userId, CancellationToken ct) =>
            Task.FromResult(new NotificationRecipient(null, ["test-device-token"], allowPush));
    }
}
