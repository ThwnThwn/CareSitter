using System.Text.Json;
using CareSitter.Contracts.Nutrition;
using Npgsql;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class BeneficiaryHealthSnapshotReader(NpgsqlDataSource dataSource) : IBeneficiaryHealthSnapshotReader
{
    public async Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid ownerId,Guid beneficiaryId,CancellationToken ct=default)
    {
        await using var connection=await dataSource.OpenConnectionAsync(ct);
        await using var transaction=await connection.BeginTransactionAsync(ct);
        await using (var scope = new NpgsqlCommand("SELECT set_config('app.current_user_id', @owner::text, true)", connection, transaction))
        {
            scope.Parameters.AddWithValue("owner", ownerId);
            await scope.ExecuteNonQueryAsync(ct);
        }
        await using var command=new NpgsqlCommand("""
            SELECT id,health_profile_revision,date_of_birth,food_allergy_status,
              food_allergy_confirmed_at,general_note,care_instructions,mobility_note,
              care_level,health_history::text,allergies::text,chronic_conditions::text,medications::text
            FROM people.beneficiaries WHERE id=@id AND customer_id=@owner AND deleted_at IS NULL
            """,connection,transaction);
        command.Parameters.AddWithValue("owner",ownerId);command.Parameters.AddWithValue("id",beneficiaryId);
        await using var reader=await command.ExecuteReaderAsync(ct);
        if(!await reader.ReadAsync(ct)) return null;
        string? Text(int i)=>reader.IsDBNull(i)?null:reader.GetString(i);
        JsonElement? Json(int i)
        {
            if(Text(i) is not { } text) return null;
            using var document=JsonDocument.Parse(text);return document.RootElement.Clone();
        }
        return new(reader.GetGuid(0),reader.GetInt64(1),reader.IsDBNull(2)?null:reader.GetFieldValue<DateOnly>(2),reader.GetString(3),
            reader.IsDBNull(4)?null:reader.GetFieldValue<DateTimeOffset>(4),Text(5),Text(6),Text(7),Text(8),Json(9),Json(10),Json(11),Json(12));
    }
}
