using System.Text.Json;
using System.Security.Cryptography;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using Npgsql;
using NpgsqlTypes;

const int MaximumBundleBytes = 5 * 1024 * 1024;

return await RunAsync(args);

static async Task<int> RunAsync(string[] arguments)
{
    try
    {
        if (arguments.Length == 0) return Usage();
        return arguments[0] switch
        {
            "validate" when arguments.Length == 2 => await ValidateAsync(arguments[1]),
            "release-check" when arguments.Length == 3 => await ReleaseCheckAsync(arguments[1], arguments[2]),
            "import" when arguments.Length is 2 or 3 && (arguments.Length == 2 || arguments[2] == "--dry-run") =>
                await ImportAsync(arguments[1], arguments.Length == 3),
            "review" when arguments.Length == 3 => await TransitionAsync("review_catalog_bundle", arguments[1], arguments[2]),
            "publish" when arguments.Length == 3 => await TransitionAsync("publish_catalog_bundle", arguments[1], arguments[2]),
            "retire" when arguments.Length == 3 => await RetireAsync(arguments[1], arguments[2]),
            _ => Usage()
        };
    }
    catch (CatalogToolException error)
    {
        Write(new { ok = false, error = error.Message });
        return error.ExitCode;
    }
    catch (PostgresException error)
    {
        Write(new { ok = false, error = error.MessageText, sqlState = error.SqlState });
        return 4;
    }
    catch (NpgsqlException)
    {
        Write(new { ok = false, error = "Catalog database operation failed." });
        return 4;
    }
}

static async Task<int> ValidateAsync(string path)
{
    var (_, result) = await ReadAndValidateAsync(path);
    Write(new { ok = result.IsValid, issues = result.Issues });
    return result.IsValid ? 0 : 2;
}

static async Task<int> ReleaseCheckAsync(string bundlePath, string evidencePath)
{
    var (bundle, bundleResult) = await ReadAndValidateAsync(bundlePath);
    var evidenceFile = new FileInfo(Path.GetFullPath(evidencePath));
    if (!evidenceFile.Exists) throw new CatalogToolException("Catalog release evidence file was not found.", 2);
    if (evidenceFile.Length is 0 or > MaximumBundleBytes) throw new CatalogToolException("Catalog release evidence must be between 1 byte and 5 MiB.", 2);
    try
    {
        var evidence = NutritionJson.Read<CatalogReleaseEvidence>(await File.ReadAllTextAsync(evidenceFile.FullName));
        var digest = Convert.ToHexString(SHA256.HashData(await File.ReadAllBytesAsync(Path.GetFullPath(bundlePath)))).ToLowerInvariant();
        var releaseResult = CatalogReleaseValidator.Validate(bundle, evidence, digest);
        Write(new
        {
            ok = releaseResult.IsReleaseReady,
            bundleValid = bundleResult.IsValid,
            releaseReady = releaseResult.IsReleaseReady,
            bundleFileSha256 = digest,
            issues = releaseResult.Issues,
            combinations = releaseResult.Combinations
        });
        return releaseResult.IsReleaseReady ? 0 : 2;
    }
    catch (JsonException error)
    {
        throw new CatalogToolException($"Catalog release evidence JSON is invalid at {error.Path ?? "$"}.", 2);
    }
}

static async Task<int> ImportAsync(string path, bool dryRun)
{
    var (bundle, result) = await ReadAndValidateAsync(path);
    if (!result.IsValid)
    {
        Write(new { ok = false, dryRun, issues = result.Issues });
        return 2;
    }
    if (dryRun)
    {
        Write(new { ok = true, dryRun = true, packageKey = bundle.PackageKey, issues = result.Issues });
        return 0;
    }
    if (bundle.PackageKey.EndsWith("-technical-draft", StringComparison.Ordinal))
        throw new CatalogToolException("Technical-draft packages can be validated and dry-run only; create a reviewed release artifact before import.", 2);

    await using var connection = await OpenAsync();
    await using var command = new NpgsqlCommand("SELECT nutrition.import_catalog_bundle(@id,@key,@payload)", connection);
    command.Parameters.AddWithValue("id", Guid.NewGuid());
    command.Parameters.AddWithValue("key", bundle.PackageKey);
    command.Parameters.AddWithValue("payload", NpgsqlDbType.Jsonb, NutritionJson.Write(bundle));
    WriteJson(await command.ExecuteScalarAsync());
    return 0;
}

static async Task<int> TransitionAsync(string function, string idText, string digest)
{
    if (!Guid.TryParse(idText, out var id) || id == Guid.Empty) throw new CatalogToolException("Package ID must be a non-empty UUID.", 2);
    if (digest.Length != 64 || digest.Any(character => !Uri.IsHexDigit(character))) throw new CatalogToolException("Digest must be a SHA-256 hexadecimal value.", 2);
    await using var connection = await OpenAsync();
    await using var command = new NpgsqlCommand($"SELECT nutrition.{function}(@id,@digest)", connection);
    command.Parameters.AddWithValue("id", id);
    command.Parameters.AddWithValue("digest", digest.ToLowerInvariant());
    WriteJson(await command.ExecuteScalarAsync());
    return 0;
}

static async Task<int> RetireAsync(string idText, string reason)
{
    if (!Guid.TryParse(idText, out var id) || id == Guid.Empty) throw new CatalogToolException("Package ID must be a non-empty UUID.", 2);
    if (string.IsNullOrWhiteSpace(reason) || reason.Trim().Length < 5) throw new CatalogToolException("Retirement reason must contain at least five characters.", 2);
    await using var connection = await OpenAsync();
    await using var command = new NpgsqlCommand("SELECT nutrition.retire_catalog_bundle(@id,@reason)", connection);
    command.Parameters.AddWithValue("id", id);
    command.Parameters.AddWithValue("reason", reason.Trim());
    WriteJson(await command.ExecuteScalarAsync());
    return 0;
}

static async Task<(CatalogBundle Bundle, CatalogValidationResult Result)> ReadAndValidateAsync(string path)
{
    var file = new FileInfo(Path.GetFullPath(path));
    if (!file.Exists) throw new CatalogToolException("Catalog bundle file was not found.", 2);
    if (file.Length is 0 or > MaximumBundleBytes) throw new CatalogToolException("Catalog bundle must be between 1 byte and 5 MiB.", 2);
    try
    {
        var bundle = NutritionJson.Read<CatalogBundle>(await File.ReadAllTextAsync(file.FullName));
        return (bundle, CatalogBundleValidator.Validate(bundle));
    }
    catch (JsonException error)
    {
        throw new CatalogToolException($"Catalog bundle JSON is invalid at {error.Path ?? "$"}.", 2);
    }
}

static async Task<NpgsqlConnection> OpenAsync()
{
    var connectionString = Environment.GetEnvironmentVariable("NUTRITION_CATALOG_CONNECTION");
    if (string.IsNullOrWhiteSpace(connectionString)) throw new CatalogToolException("Set NUTRITION_CATALOG_CONNECTION for this catalog role.", 3);
    var connection = new NpgsqlConnection(connectionString);
    await connection.OpenAsync();
    return connection;
}

static void WriteJson(object? databaseValue)
{
    if (databaseValue is not string json) throw new CatalogToolException("Catalog database returned no result.", 4);
    using var document = JsonDocument.Parse(json);
    Console.WriteLine(JsonSerializer.Serialize(document.RootElement, NutritionJson.Options));
}

static void Write<T>(T value) => Console.WriteLine(JsonSerializer.Serialize(value, NutritionJson.Options));

static int Usage()
{
    Console.Error.WriteLine("Usage: catalog-tool validate <bundle.json> | release-check <bundle.json> <evidence.json> | import <bundle.json> [--dry-run] | review <package-id> <digest> | publish <package-id> <digest> | retire <package-id> <reason>");
    return 1;
}

sealed class CatalogToolException(string message, int exitCode) : Exception(message)
{
    public int ExitCode { get; } = exitCode;
}
