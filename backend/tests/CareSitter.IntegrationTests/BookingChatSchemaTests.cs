using Npgsql;

namespace CareSitter.IntegrationTests;

[Trait("Category", "PostgreSQL")]
public sealed class BookingChatSchemaTests : IAsyncLifetime
{
    private PostgresRaceTestDatabase _database = null!;

    public async Task InitializeAsync() =>
        _database = await PostgresRaceTestDatabase.CreateAsync();

    public async Task DisposeAsync()
    {
        if (_database is not null)
            await _database.DisposeAsync();
    }

    [PostgresFact]
    public async Task Migration_44_creates_the_booking_owned_chat_schema()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT count(*)
            FROM information_schema.tables
            WHERE table_schema = 'booking'
              AND table_name = ANY (ARRAY[
                'booking_chat_conversations',
                'booking_chat_epochs',
                'booking_chat_messages',
                'booking_chat_read_cursors',
                'booking_chat_activity_events',
                'booking_chat_outbox',
                'booking_chat_reports'
              ]);
            """, connection);

        Assert.Equal(7L, (long)(await command.ExecuteScalarAsync())!);
    }

    [PostgresFact]
    public async Task Chat_schema_protects_scope_idempotency_and_body_privacy()
    {
        await using var connection = await _database.OpenConnectionAsync();
        await using var command = new NpgsqlCommand("""
            SELECT
              (SELECT count(*) FROM pg_indexes
               WHERE schemaname = 'booking'
                 AND indexname = ANY (ARRAY[
                   'uq_booking_chat_current_epoch',
                   'uq_booking_chat_user_message_key',
                   'uq_booking_chat_system_event',
                   'uq_booking_chat_report'
                 ])) AS protected_indexes,
              (SELECT count(*) FROM information_schema.columns
               WHERE table_schema = 'booking'
                 AND table_name = 'booking_chat_outbox'
                 AND column_name IN ('body', 'body_snapshot', 'template_params', 'payload')) AS leaked_body_columns,
              (SELECT string_agg(pg_get_constraintdef(oid), ' ')
               FROM pg_constraint
               WHERE conrelid = 'booking.booking_chat_messages'::regclass) AS message_constraints;
            """, connection);

        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        Assert.Equal(4L, reader.GetInt64(0));
        Assert.Equal(0L, reader.GetInt64(1));
        var constraints = reader.GetString(2);
        Assert.Contains("octet_length", constraints, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("source_event_id", constraints, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("idempotency_key", constraints, StringComparison.OrdinalIgnoreCase);
    }
}
