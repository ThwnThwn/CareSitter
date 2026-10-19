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
#region K3. Epoch: cách ly, rò rỉ, cursor vào vùng ẩn

    [PostgresFact]
    public async Task K3_EpochIsolation_CaregiverSeesOnlyCurrentEpoch_CustomerSeesAll()
    {
        await using var db = CreateDb();
        // Setup 2 epochs: Epoch 1 (50 tin, Caregiver 1), Epoch 2 (200 tin, Caregiver 2)
        var seed = await SeedTwoEpochConversationAsync(db, epoch1Messages: 50, epoch2Messages: 200);

        var customerChat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.Caregiver2ProfileId, seed.Caregiver2UserId);
        var caregiver2Chat = CreateChatService(db, seed.Caregiver2UserId, "CAREGIVER", seed.Caregiver2ProfileId, seed.Caregiver2UserId);
        var caregiver1Chat = CreateChatService(db, seed.Caregiver1UserId, "CAREGIVER", seed.Caregiver1ProfileId, seed.Caregiver1UserId);

        // 1. Customer thấy đủ 250 tin qua phân trang backward
        var customerAll = new List<BookingChatMessageResponse>();
        string? cursor = null;
        while (true)
        {
            var p = await customerChat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: cursor, limit: 100);
            Assert.True(p.IsSuccess);
            if (p.Value.Items.Count == 0) break;
            customerAll.AddRange(p.Value.Items);
            if (!p.Value.HasMoreBefore) break;
            cursor = p.Value.PreviousCursor;
        }
        Assert.Equal(250, customerAll.Count);

        // 2. Caregiver 2 chỉ thấy 200 tin thuộc Epoch 2 (sequence 51..250) qua phân trang backward
        var caregiver2All = new List<BookingChatMessageResponse>();
        cursor = null;
        while (true)
        {
            var p = await caregiver2Chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: cursor, limit: 100);
            Assert.True(p.IsSuccess);
            if (p.Value.Items.Count == 0) break;
            caregiver2All.AddRange(p.Value.Items);
            if (!p.Value.HasMoreBefore) break;
            cursor = p.Value.PreviousCursor;
        }
        Assert.Equal(200, caregiver2All.Count);
        Assert.All(caregiver2All, m => Assert.True(m.Sequence >= 51 && m.Sequence <= 250));

        // 3. Caregiver 2 lật lùi về sequence 51 -> hasMoreBefore bắt buộc phải false (không lộ sự tồn tại của 50 tin Epoch 1)
        var cg2FirstBatch = await caregiver2Chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: null, limit: 100);
        Assert.True(cg2FirstBatch.IsSuccess);
        var cg2SecondBatch = await caregiver2Chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: cg2FirstBatch.Value.PreviousCursor, limit: 100);
        Assert.True(cg2SecondBatch.IsSuccess);
        Assert.Equal(51, cg2SecondBatch.Value.Items[0].Sequence);
        Assert.False(cg2SecondBatch.Value.HasMoreBefore, "Caregiver 2 không được thấy hasMoreBefore=true ở biên Epoch 2.");

        // 4. Caregiver 1 sau bàn giao (Epoch 1 ended): Gọi API nhận NotFound
        var cg1Result = await caregiver1Chat.GetMessagesAsync(seed.BookingId, null, null, 50);
        Assert.True(cg1Result.IsFailure);
        Assert.Equal("booking.chat.not_found", cg1Result.Error.Code);
    }

    [PostgresFact]
    public async Task K3_CursorPointingToHiddenEpoch1Sequence_ReturnsEmpty_DoesNotLeakMessages()
    {
        await using var db = CreateDb();
        var seed = await SeedTwoEpochConversationAsync(db, epoch1Messages: 50, epoch2Messages: 200);

        var caregiver2Chat = CreateChatService(db, seed.Caregiver2UserId, "CAREGIVER", seed.Caregiver2ProfileId, seed.Caregiver2UserId);

        // Tạo một cursor hợp lệ cho Caregiver 2 nhưng có position = 25 (nằm trong Epoch 1)
        var syntheticCursor = CreateSignedCursor(seed.ConversationId, seed.Caregiver2UserId, scopeVersion: 1,
            direction: "before", position: 25, upperBound: 250);

        var result = await caregiver2Chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: syntheticCursor, limit: 50);
        Assert.True(result.IsSuccess);
        Assert.Empty(result.Value.Items);
        Assert.False(result.Value.HasMoreBefore);
    }

    #endregion

    #region K4. UpperBound và ghi đồng thời

    [PostgresFact]
    public async Task K4A_Deterministic_UpperBoundSnapshotStability()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 250, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // 1. Lấy trang 1: 100 tin (151..250), snapshot upperBound = 250
        var page1 = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: null, limit: 100);
        Assert.True(page1.IsSuccess);
        Assert.Equal(250, page1.Value.HighWatermark);
        Assert.Equal(250, page1.Value.Items[^1].Sequence);

        // 2. Chèn tin nhắn 251 và 252 vào database
        await InsertRawMessageAsync(db, seed.ConversationId, seed.EpochId, sequence: 251, seed.CustomerId);
        await InsertRawMessageAsync(db, seed.ConversationId, seed.EpochId, sequence: 252, seed.CustomerId);

        // 3. Lấy trang 2 bằng beforeCursor: upperBound vẫn phải là 250, nhận đúng 51..150
        var page2 = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: page1.Value.PreviousCursor, limit: 100);
        Assert.True(page2.IsSuccess);
        Assert.Equal(250, page2.Value.HighWatermark);
        Assert.Equal(100, page2.Value.Items.Count);
        Assert.Equal(51, page2.Value.Items[0].Sequence);
        Assert.Equal(150, page2.Value.Items[^1].Sequence);

        // 4. Dùng afterCursor vượt upperBound 250 -> bung upperBound theo allowedHigh mới (252)
        var afterCursor = page1.Value.NextCursor;
        var newItemsPage = await chat.GetMessagesAsync(seed.BookingId, afterCursor: afterCursor, beforeCursor: null, limit: 100);
        Assert.True(newItemsPage.IsSuccess);
        Assert.Equal(2, newItemsPage.Value.Items.Count);
        Assert.Equal(251, newItemsPage.Value.Items[0].Sequence);
        Assert.Equal(252, newItemsPage.Value.Items[1].Sequence);
        Assert.Equal(252, newItemsPage.Value.HighWatermark);
    }

    [PostgresFact]
    public async Task K4B_LockObservation_TransactionB_WaitsForTransactionA_RowLock()
    {
        await using var dbA = CreateDb();
        await using var dbB = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(dbA, messageCount: 5, jumbleTimestamps: false);

        var chatB = CreateChatService(dbB, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // Giao dịch A mở và giữ FOR UPDATE trên conversation row
        await using var txA = await dbA.Database.BeginTransactionAsync();
        await dbA.Database.ExecuteSqlInterpolatedAsync(
            $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {seed.BookingId} FOR UPDATE");

        // Giao dịch B gọi SendAsync trong Task riêng.
        var taskB = Task.Run(async () =>
        {
            await using var scopedDb = CreateDb();
            var scopedChat = CreateChatService(scopedDb, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);
            return await scopedChat.SendAsync(seed.BookingId, Guid.NewGuid(),
                new BookingChatSendRequest(seed.EpochId, "text", "Tin nhan tu giao dich B", null, null, null));
        });

        var lockObserved = false;
        var transactionCompleted = false;
        try
        {
            // Query text do EF/Npgsql sinh ra có thể thay đổi alias/parameter, vì vậy
            // quan sát wait_event_type thay vì phụ thuộc chuỗi SQL cụ thể.
            await using var checkConn = await Database.OpenConnectionAsync();
            await using var checkCmd = new NpgsqlCommand("""
                SELECT count(*)
                FROM pg_stat_activity
                WHERE datname = current_database()
                  AND pid <> pg_backend_pid()
                  AND wait_event_type = 'Lock'
                  AND state = 'active';
                """, checkConn);

            for (var attempt = 0; attempt < 100 && !taskB.IsCompleted; attempt++)
            {
                var waitingLocks = Convert.ToInt64(await checkCmd.ExecuteScalarAsync());
                if (waitingLocks > 0)
                {
                    lockObserved = true;
                    break;
                }

                await Task.Delay(50);
            }

            // Giải phóng khóa của A dù assertion quan sát lock có thất bại, tránh để
            // task B treo và làm hỏng cleanup của fixture.
            await txA.CommitAsync();
            transactionCompleted = true;

            var resultB = await taskB;
            Assert.True(lockObserved, "Phải quan sát được giao dịch B đang chờ một lock PostgreSQL.");

            // Giao dịch B hoàn thành thành công và có sequence 6 (tiếp nối 5)
            Assert.True(resultB.IsSuccess, resultB.Error.Message);
            Assert.Equal(6, resultB.Value.Sequence);
        }
        finally
        {
            if (!transactionCompleted)
                await txA.RollbackAsync();

            if (!taskB.IsCompleted)
                await taskB;
        }
    }

    [PostgresFact]
    public async Task K4B_Rollback_PreservesContinuousSequence_WithoutGap()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 10, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // Mô phỏng 1 transaction ghi thất bại giữa chừng rồi rollback
        await using (var failedTx = await db.Database.BeginTransactionAsync())
        {
            var conversation = await db.BookingChatConversations.FromSqlInterpolated(
                $"SELECT * FROM booking.booking_chat_conversations WHERE booking_id = {seed.BookingId} FOR UPDATE")
                .SingleAsync();

            conversation.AppendMessage(DateTimeOffset.UtcNow); // last_sequence = 11 trong memory
            await db.SaveChangesAsync();

            // Cố tình rollback
            await failedTx.RollbackAsync();
        }

        db.ChangeTracker.Clear();

        // Lần ghi tiếp theo qua chat.SendAsync
        var nextMsg = await chat.SendAsync(seed.BookingId, Guid.NewGuid(),
            new BookingChatSendRequest(seed.EpochId, "text", "Tin nhắn tiếp theo sau rollback", null, null, null));

        Assert.True(nextMsg.IsSuccess);
        // Do transaction trước rollback, last_sequence trên DB được phục hồi là 10, tin mới phải nhận sequence 11
        Assert.Equal(11, nextMsg.Value.Sequence);
    }

    [PostgresFact]
    public async Task K4B_ConcurrentAppendsAndReads_30Iterations_PassesConsistently()
    {
        // Chạy lặp lại 30 lần stress test để phát hiện flaky
        for (var run = 1; run <= 30; run++)
        {
            await using var db = CreateDb();
            var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);

            var barrier = new Barrier(3);
            var writeTask1 = Task.Run(async () =>
            {
                await using var scopedDb = CreateDb();
                var chat = CreateChatService(scopedDb, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);
                barrier.SignalAndWait();
                return await chat.SendAsync(seed.BookingId, Guid.NewGuid(),
                    new BookingChatSendRequest(seed.EpochId, "text", "Writer 1 Msg", null, null, null));
            });

            var writeTask2 = Task.Run(async () =>
            {
                await using var scopedDb = CreateDb();
                var chat = CreateChatService(scopedDb, seed.CaregiverUserId, "CAREGIVER", seed.CaregiverProfileId, seed.CaregiverUserId);
                barrier.SignalAndWait();
                return await chat.SendAsync(seed.BookingId, Guid.NewGuid(),
                    new BookingChatSendRequest(seed.EpochId, "text", "Writer 2 Msg", null, null, null));
            });

            var readTask = Task.Run(async () =>
            {
                await using var scopedDb = CreateDb();
                var chat = CreateChatService(scopedDb, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);
                barrier.SignalAndWait();
                var pages = new List<BookingChatMessageResponse>();
                for (var i = 0; i < 3; i++)
                {
                    var p = await chat.GetMessagesAsync(seed.BookingId, null, null, 10);
                    if (p.IsSuccess) pages.AddRange(p.Value.Items);
                    await Task.Delay(5);
                }
                return pages;
            });

            await Task.WhenAll(writeTask1, writeTask2, readTask);

            var res1 = await writeTask1;
            var res2 = await writeTask2;
            Assert.True(res1.IsSuccess);
            Assert.True(res2.IsSuccess);

            // Hai sequence phải là 6 và 7 (khác nhau)
            var sequences = new[] { res1.Value.Sequence, res2.Value.Sequence };
            Assert.Contains(6L, sequences);
            Assert.Contains(7L, sequences);
        }
    }

    #endregion
}
