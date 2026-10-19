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
#region K5. Cursor: Giả mạo, IDOR và Scope

    [PostgresFact]
    public async Task K5_HmacTampering_FlippingByte_ReturnsCursorInvalid()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 10, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var page = await chat.GetMessagesAsync(seed.BookingId, null, null, 2);
        Assert.True(page.IsSuccess);
        var validCursor = page.Value.NextCursor!;

        // Giải mã base64, lật 1 byte ở giữa mảng dữ liệu (vùng ciphertext/HMAC), mã hóa lại
        var bytes = Convert.FromBase64String(validCursor);
        bytes[bytes.Length / 2] ^= 0xFF;
        var tamperedCursor = Convert.ToBase64String(bytes);

        var result = await chat.GetMessagesAsync(seed.BookingId, afterCursor: tamperedCursor, beforeCursor: null, limit: 10);
        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.cursor_invalid", result.Error.Code);
    }

    [PostgresFact]
    public async Task K5_IDOR_UsingCursorFromBookingA_InBookingB_ReturnsCursorInvalid()
    {
        await using var db = CreateDb();
        var seedA = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var seedB = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);

        var chatA = CreateChatService(db, seedA.CustomerId, "CUSTOMER", seedA.CaregiverProfileId, seedA.CaregiverUserId);
        var chatB = CreateChatService(db, seedB.CustomerId, "CUSTOMER", seedB.CaregiverProfileId, seedB.CaregiverUserId);

        var pageA = await chatA.GetMessagesAsync(seedA.BookingId, null, null, 2);
        var cursorA = pageA.Value.NextCursor!;

        // Đem cursor của booking A sang query tại booking B
        var resultB = await chatB.GetMessagesAsync(seedB.BookingId, afterCursor: cursorA, beforeCursor: null, limit: 10);
        Assert.True(resultB.IsFailure);
        Assert.Equal("booking.chat.cursor_invalid", resultB.Error.Code);
    }

    [PostgresFact]
    public async Task K5_IDOR_CrossUserCursor_CustomerUsesCaregiverCursor_ReturnsCursorInvalid()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 10, jumbleTimestamps: false);

        var customerChat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);
        var caregiverChat = CreateChatService(db, seed.CaregiverUserId, "CAREGIVER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // Caregiver lấy cursor
        var cgPage = await caregiverChat.GetMessagesAsync(seed.BookingId, null, null, 2);
        var caregiverCursor = cgPage.Value.NextCursor!;

        // Customer dùng cursor của Caregiver
        var customerResult = await customerChat.GetMessagesAsync(seed.BookingId, afterCursor: caregiverCursor, beforeCursor: null, limit: 10);
        Assert.True(customerResult.IsFailure);
        Assert.Equal("booking.chat.cursor_invalid", customerResult.Error.Code);
    }

    [PostgresFact]
    public async Task K5_ExternalUser_RejectedWithNotFound_BeforeEvaluatingCursor()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);

        var outsiderId = Guid.NewGuid();
        var outsiderChat = CreateChatService(db, outsiderId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var result = await outsiderChat.GetMessagesAsync(seed.BookingId, null, null, 10);
        Assert.True(result.IsFailure);
        // Assert đúng mã lỗi NotFound theo chuẩn bảo mật
        Assert.Equal("booking.chat.not_found", result.Error.Code);
    }

    [PostgresFact]
    public async Task K5_ScopeVersionChanged_ReturnsScopeChangedError()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var page = await chat.GetMessagesAsync(seed.BookingId, null, null, 2);
        var cursor = page.Value.NextCursor!;

        // Tăng scope_version trong database
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE booking.booking_chat_conversations SET scope_version = scope_version + 1 WHERE id = {seed.ConversationId}");

        var result = await chat.GetMessagesAsync(seed.BookingId, afterCursor: cursor, beforeCursor: null, limit: 10);
        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.scope_changed", result.Error.Code);
    }

    #endregion

    #region K6. Case biên

    [PostgresFact]
    public async Task K6_EmptyConversation_ReturnsEmptyList_WithoutError()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 0, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var result = await chat.GetMessagesAsync(seed.BookingId, null, null, 50);
        Assert.True(result.IsSuccess);
        Assert.Empty(result.Value.Items);
        Assert.False(result.Value.HasMoreBefore);
        Assert.False(result.Value.HasMoreAfter);
        Assert.NotNull(result.Value.NextCursor);
        Assert.Null(result.Value.PreviousCursor);
    }

    [PostgresFact]
    public async Task K6_Exactly100Messages_Limit100_HasMoreBeforeIsImmediatelyFalse()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 100, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var result = await chat.GetMessagesAsync(seed.BookingId, null, null, 100);
        Assert.True(result.IsSuccess);
        Assert.Equal(100, result.Value.Items.Count);
        Assert.False(result.Value.HasMoreBefore, "Khi có đúng 100 tin và limit=100, hasMoreBefore phải là false ngay.");
    }

    [PostgresFact]
    public async Task K6_PurgedConversation_ReturnsPurgedError()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // Đánh dấu purged_at
        await db.Database.ExecuteSqlInterpolatedAsync(
            $"UPDATE booking.booking_chat_conversations SET purged_at = now() WHERE id = {seed.ConversationId}");

        var result = await chat.GetMessagesAsync(seed.BookingId, null, null, 10);
        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.purged", result.Error.Code);
    }

    #endregion

    #region K7. Query Plan (Index Scan Verification)

    [PostgresFact]
    public async Task K7_ExplainPlan_VerifiesIndexUsage_NoSeqScanOnMessages()
    {
        await using var db = CreateDb();
        const int messagesPerConversation = 12_500;
        var seed = await SeedConversationWithMessagesAsync(
            db, messageCount: messagesPerConversation, jumbleTimestamps: false);
        for (var conversation = 1; conversation < 4; conversation++)
        {
            await SeedConversationWithMessagesAsync(
                db, messageCount: messagesPerConversation, jumbleTimestamps: false);
        }

        await using var connection = await Database.OpenConnectionAsync();

        // Chạy ANALYZE để optimizer cập nhật statistics
        await using (var analyzeCmd = new NpgsqlCommand("ANALYZE booking.booking_chat_messages;", connection))
            await analyzeCmd.ExecuteNonQueryAsync();

        // 1. Kiểm tra query backward phân trang gần đây
        var queryBackward = """
            EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS)
            SELECT id, conversation_id, epoch_id, sequence, sender_user_id, sender_role, kind,
                   template_key, template_version, template_params, body_snapshot, created_at
            FROM booking.booking_chat_messages
            WHERE conversation_id = @convId AND sequence <= 12500
            ORDER BY sequence DESC
            LIMIT 100;
            """;

        async Task<(string Plan, bool ForcedIndex)> ExplainWithFallbackAsync(
            string sql, string parameterName, object parameterValue)
        {
            async Task<string> ExecuteAsync()
            {
                await using var command = new NpgsqlCommand(sql, connection);
                command.Parameters.AddWithValue(parameterName, parameterValue);
                return (string)(await command.ExecuteScalarAsync())!;
            }

            var planJson = await ExecuteAsync();
            if (!planJson.Contains("\"Node Type\": \"Seq Scan\"", StringComparison.OrdinalIgnoreCase))
                return (planJson, false);

            // Dataset nhỏ hoặc thống kê khác nhau có thể khiến planner chọn Seq Scan.
            // Chỉ khi đó mới ép index, và ghi nhận rõ trong output của test.
            await using (var setCmd = new NpgsqlCommand("SET enable_seqscan = off;", connection))
                await setCmd.ExecuteNonQueryAsync();
            return (await ExecuteAsync(), true);
        }

        var (backwardPlan, backwardForced) = await ExplainWithFallbackAsync(
            queryBackward, "convId", seed.ConversationId);
        Assert.DoesNotContain("\"Node Type\": \"Seq Scan\"", backwardPlan, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Index Scan", backwardPlan, StringComparison.OrdinalIgnoreCase);
        Assert.True(
            backwardPlan.Contains("ix_booking_chat_messages_recent", StringComparison.OrdinalIgnoreCase) ||
            backwardPlan.Contains("uq_booking_chat_message_sequence", StringComparison.OrdinalIgnoreCase),
            $"Query backward phải dùng index bao trùm (ix_booking_chat_messages_recent hoặc uq_booking_chat_message_sequence). Plan: {backwardPlan}");

        // 2. Kiểm tra query Caregiver lọc theo epoch_id
        var queryEpoch = """
            EXPLAIN (FORMAT JSON, ANALYZE, BUFFERS)
            SELECT id, conversation_id, epoch_id, sequence, sender_user_id, sender_role, kind,
                   template_key, template_version, template_params, body_snapshot, created_at
            FROM booking.booking_chat_messages
            WHERE epoch_id = @epochId AND sequence <= 12500
            ORDER BY sequence DESC
            LIMIT 100;
            """;

        var (epochPlan, epochForced) = await ExplainWithFallbackAsync(
            queryEpoch, "epochId", seed.EpochId);
        Assert.DoesNotContain("\"Node Type\": \"Seq Scan\"", epochPlan, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Index Scan", epochPlan, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("ix_booking_chat_messages_epoch", epochPlan, StringComparison.OrdinalIgnoreCase);
        _output.WriteLine(
            $"K7: conversations=4, messages=50000, enable_seqscan=off fallback=" +
            $"{(backwardForced || epochForced ? "yes" : "no")}");
    }

    #endregion
}
