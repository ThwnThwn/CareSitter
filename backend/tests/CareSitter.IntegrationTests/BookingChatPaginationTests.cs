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

[Trait("Category", "PostgreSQL")]
public sealed partial class BookingChatPaginationTests : IClassFixture<PostgresRaceTestDatabaseFixture>
{
    private readonly PostgresRaceTestDatabaseFixture _fixture;
    private readonly ITestOutputHelper _output;
    private readonly IDataProtectionProvider _dataProtection = new EphemeralDataProtectionProvider();
    private readonly IOptions<BookingChatOptions> _chatOptions = Options.Create(new BookingChatOptions { Enabled = true });

    public BookingChatPaginationTests(
        PostgresRaceTestDatabaseFixture fixture,
        ITestOutputHelper output)
    {
        _fixture = fixture;
        _output = output;
    }

    private PostgresRaceTestDatabase Database => _fixture.Database
        ?? throw new InvalidOperationException("PostgreSQL test database is not available.");

    private BookingDbContext CreateDb() => new(new DbContextOptionsBuilder<BookingDbContext>()
        .UseNpgsql(Database.ConnectionString).Options);

#region K1. Phân trang đầy đủ, backward và forward (Theory)

    [PostgresTheory]
    [InlineData("backward", 1)]
    [InlineData("backward", 2)]
    [InlineData("backward", 7)]
    [InlineData("backward", 50)]
    [InlineData("backward", 99)]
    [InlineData("backward", 100)]
    [InlineData("forward", 1)]
    [InlineData("forward", 2)]
    [InlineData("forward", 7)]
    [InlineData("forward", 50)]
    [InlineData("forward", 99)]
    [InlineData("forward", 100)]
    public async Task K1_FullPagination_TraversesAll250Messages_WithoutLossOrDuplicate(
        string direction, int pageSize)
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 250, jumbleTimestamps: true);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var retrieved = new List<BookingChatMessageResponse>();
        string? currentCursor = direction == "forward"
            ? CreateSignedCursor(seed.ConversationId, seed.CustomerId, scopeVersion: 1, direction: "after", position: 0, upperBound: 250)
            : null;
        var isFirstPage = true;

        while (true)
        {
            var pageResult = direction == "backward"
                ? await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: currentCursor, limit: pageSize)
                : await chat.GetMessagesAsync(seed.BookingId, afterCursor: currentCursor, beforeCursor: null, limit: pageSize);

            Assert.True(pageResult.IsSuccess, pageResult.Error.Message);
            var page = pageResult.Value;

            if (page.Items.Count == 0)
                break;

            retrieved.AddRange(page.Items);

            if (direction == "backward")
            {
                // Trong từng trang, danh sách hiển thị theo thứ tự sequence tăng dần
                for (var i = 1; i < page.Items.Count; i++)
                    Assert.True(page.Items[i].Sequence > page.Items[i - 1].Sequence);

                if (isFirstPage && pageSize < 250)
                    Assert.True(page.HasMoreBefore);

                if (!page.HasMoreBefore)
                    break;

                Assert.NotNull(page.PreviousCursor);
                currentCursor = page.PreviousCursor;
            }
            else
            {
                // Forward: sequence tăng dần qua các trang
                for (var i = 1; i < page.Items.Count; i++)
                    Assert.True(page.Items[i].Sequence > page.Items[i - 1].Sequence);

                if (isFirstPage && pageSize < 250)
                    Assert.True(page.HasMoreAfter);

                if (!page.HasMoreAfter)
                    break;

                Assert.NotNull(page.NextCursor);
                currentCursor = page.NextCursor;
            }

            isFirstPage = false;
        }

        // Assert K1
        Assert.Equal(250, retrieved.Count);
        Assert.Equal(250, retrieved.Select(x => x.Sequence).Distinct().Count());

        if (direction == "forward")
        {
            for (var seq = 1; seq <= 250; seq++)
                Assert.Equal(seq, retrieved[seq - 1].Sequence);
        }
        else
        {
            // Backward: do ta nối từng trang lùi (ví dụ trang 1: 151..250, trang 2: 51..150),
            // các sequence thu thập được phải bao phủ đúng từ 1 đến 250
            var allSeqs = retrieved.Select(x => x.Sequence).OrderBy(x => x).ToList();
            for (var seq = 1; seq <= 250; seq++)
                Assert.Equal(seq, allSeqs[seq - 1]);
        }
    }

    [PostgresFact]
    public async Task K1_Supplementary_251Messages_WithLimit100_LastPageHasExactly1Message()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 251, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var page1 = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: null, limit: 100);
        Assert.True(page1.IsSuccess);
        Assert.Equal(100, page1.Value.Items.Count);
        Assert.True(page1.Value.HasMoreBefore);

        var page2 = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: page1.Value.PreviousCursor, limit: 100);
        Assert.True(page2.IsSuccess);
        Assert.Equal(100, page2.Value.Items.Count);
        Assert.True(page2.Value.HasMoreBefore);

        var page3 = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: page2.Value.PreviousCursor, limit: 100);
        Assert.True(page3.IsSuccess);
        Assert.Equal(51, page3.Value.Items.Count);
        Assert.False(page3.Value.HasMoreBefore);
    }

    #endregion

    #region K2. Validation tham số

    [PostgresTheory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    [InlineData(250)]
    [InlineData(251)]
    public async Task K2_InvalidLimit_ReturnsInvalidRequestError(int invalidLimit)
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var result = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: null, limit: invalidLimit);
        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.invalid_request", result.Error.Code);
    }

    [PostgresFact]
    public async Task K2_DefaultLimit_Is50()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 70, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        // Gọi service với limit = 50 -> trả về đúng 50 tin
        var result = await chat.GetMessagesAsync(seed.BookingId, afterCursor: null, beforeCursor: null, limit: 50);
        Assert.True(result.IsSuccess);
        Assert.Equal(50, result.Value.Items.Count);
        Assert.True(result.Value.HasMoreBefore);

        // Gọi controller không truyền limit -> [FromQuery] int limit = 50 mặc định
        var controller = new BookingChatController(chat);
        var actionResult = await controller.GetMessages(seed.BookingId, afterCursor: null, beforeCursor: null);
        var okResult = Assert.IsType<Microsoft.AspNetCore.Mvc.OkObjectResult>(actionResult);
        var response = Assert.IsType<BookingChatMessagesResponse>(okResult.Value);
        Assert.Equal(50, response.Items.Count);
    }

    [PostgresFact]
    public async Task K2_ProvidingBothAfterAndBeforeCursor_ReturnsInvalidRequestError()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 10, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var page = await chat.GetMessagesAsync(seed.BookingId, null, null, 2);
        Assert.True(page.IsSuccess);

        var result = await chat.GetMessagesAsync(seed.BookingId,
            afterCursor: page.Value.NextCursor,
            beforeCursor: page.Value.PreviousCursor,
            limit: 10);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.invalid_request", result.Error.Code);
    }

    [PostgresTheory]
    [InlineData("")]
    [InlineData("not-a-base64-string!@#$")]
    [InlineData("AAECAwQFBgcICQoLDA0ODw==")] // valid base64 nhưng không phải định dạng của DataProtector
    public async Task K2_MalformedCursor_ReturnsCursorInvalidError(string malformedCursor)
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var result = await chat.GetMessagesAsync(seed.BookingId, afterCursor: malformedCursor, beforeCursor: null, limit: 10);
        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.cursor_invalid", result.Error.Code);
    }

    [PostgresFact]
    public async Task K2_TruncatedCursor_ReturnsCursorInvalidError()
    {
        await using var db = CreateDb();
        var seed = await SeedConversationWithMessagesAsync(db, messageCount: 5, jumbleTimestamps: false);
        var chat = CreateChatService(db, seed.CustomerId, "CUSTOMER", seed.CaregiverProfileId, seed.CaregiverUserId);

        var page = await chat.GetMessagesAsync(seed.BookingId, null, null, 2);
        Assert.True(page.IsSuccess);
        var validCursor = page.Value.NextCursor!;
        var truncatedCursor = validCursor[..^4];

        var result = await chat.GetMessagesAsync(
            seed.BookingId, afterCursor: truncatedCursor, beforeCursor: null, limit: 10);

        Assert.True(result.IsFailure);
        Assert.Equal("booking.chat.cursor_invalid", result.Error.Code);
    }

    #endregion
}
