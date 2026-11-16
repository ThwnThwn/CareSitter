using CareSitter.Modules.Booking;

namespace CareSitter.ApiHost.Jobs;

internal static class BookingChatBackfill
{
    public const string Argument = "--booking-chat-backfill";

    public static async Task RunAsync(IServiceProvider services)
    {
        await using var scope = services.CreateAsyncScope();
        var (result, remaining) = await BookingModule.BackfillMissingChatConversationsAsync(
            scope.ServiceProvider, batchSize: 200);
        Console.WriteLine($"Booking chat backfill: examined={result.Examined}, " +
            $"created={result.ConversationsCreated}, remaining={remaining}");
    }
}
