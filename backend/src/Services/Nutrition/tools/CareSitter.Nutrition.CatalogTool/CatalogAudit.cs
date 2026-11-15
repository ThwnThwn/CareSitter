using System.Data;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using CareSitter.Nutrition.Application;
using CareSitter.Nutrition.Application.Catalog;
using CareSitter.Nutrition.Domain;
using Npgsql;

public static class CatalogAudit
{
    public static async Task<int> RunAsync(string[] arguments)
    {
        string? bundlePath = null, demoKey = null;
        var active = false;
        var output = Path.Combine("artifacts", "nutrition-catalog-audit");
        for (var index = 0; index < arguments.Length; index++)
        {
            switch (arguments[index])
            {
                case "--active": active = true; break;
                case "--bundle" when index + 1 < arguments.Length: bundlePath = arguments[++index]; break;
                case "--demo-key" when index + 1 < arguments.Length: demoKey = arguments[++index]; break;
                case "--output" when index + 1 < arguments.Length: output = arguments[++index]; break;
                default: throw new ArgumentException("Invalid audit arguments.");
            }
        }
        if (active == (bundlePath is not null) || (!active && demoKey is not null))
            throw new ArgumentException("Choose --active or --bundle.");
        var outputRoot = Path.GetFullPath(output);
        var normalizedOutput = outputRoot.Replace('\\', '/').TrimEnd('/') + "/";
        if (normalizedOutput.Contains("/catalog/drafts/", StringComparison.OrdinalIgnoreCase) ||
            normalizedOutput.Contains("/catalog/sources/", StringComparison.OrdinalIgnoreCase))
            throw new ArgumentException("Audit output cannot be inside catalog drafts or sources.");
        // Match the service's demo configuration when inherited; --demo-key can select it explicitly.
        if (active && demoKey is null && string.Equals(Environment.GetEnvironmentVariable("NutritionCatalog__LocalDemoEnabled"), "true", StringComparison.OrdinalIgnoreCase))
            demoKey = Environment.GetEnvironmentVariable("NutritionCatalog__LocalDemoPackageKey") ?? "adult-baseline-p2a-v1-local-demo";
        var rows = new List<AuditRecipe>();
        var metadata = new List<string>();
        if (bundlePath is not null)
        {
            var file = new FileInfo(Path.GetFullPath(bundlePath));
            if (!file.Exists || file.Length is 0 or > 5 * 1024 * 1024) throw new InvalidOperationException("Invalid audit bundle size.");
            var bytes = await File.ReadAllBytesAsync(file.FullName);
            AddBundle(NutritionJson.Read<CatalogBundle>(Encoding.UTF8.GetString(bytes)), rows);
            metadata.Add("Bundle SHA-256: " + Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant());
        }
        else
        {
            var connectionString = Environment.GetEnvironmentVariable("NUTRITION_CATALOG_CONNECTION");
            if (string.IsNullOrWhiteSpace(connectionString)) throw new InvalidOperationException("Set NUTRITION_CATALOG_CONNECTION for read-only catalog access.");
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync();
            await using var transaction = await connection.BeginTransactionAsync(IsolationLevel.RepeatableRead);
            await using (var readOnly = new NpgsqlCommand("SET TRANSACTION READ ONLY", connection, transaction)) await readOnly.ExecuteNonQueryAsync();
            await using (var state = new NpgsqlCommand("SELECT revision FROM nutrition.catalog_state WHERE id=1", connection, transaction))
            {
                if (await state.ExecuteScalarAsync() is not long revision || revision < 1) throw new InvalidOperationException("Missing catalog revision.");
                metadata.Add("Published revision: " + revision.ToString(CultureInfo.InvariantCulture));
            }
            await using (var recipes = new NpgsqlCommand("SELECT payload::text FROM nutrition.recipe_versions WHERE status='published' ORDER BY id", connection, transaction))
            await using (var reader = await recipes.ExecuteReaderAsync())
                while (await reader.ReadAsync()) rows.Add(new("published", NutritionJson.Read<Recipe>(reader.GetString(0))));
            if (demoKey is not null)
            {
                await using var demo = new NpgsqlCommand("SELECT payload::text,revision,payload_digest FROM nutrition.local_demo_catalog WHERE package_key=@key", connection, transaction);
                demo.Parameters.AddWithValue("key", demoKey);
                await using var reader = await demo.ExecuteReaderAsync();
                if (!await reader.ReadAsync() || reader.IsDBNull(1) || reader.GetInt64(1) < 1 || reader.IsDBNull(2))
                    throw new InvalidOperationException("Missing demo catalog metadata.");
                var json = reader.GetString(0);
                var digest = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
                if (digest != reader.GetString(2)) throw new InvalidOperationException("Demo catalog digest mismatch.");
                var bundle = NutritionJson.Read<CatalogBundle>(json);
                if (bundle.PackageKey != demoKey) throw new InvalidOperationException("Demo catalog key mismatch.");
                AddBundle(bundle, rows);
                metadata.Add($"Demo revision: {reader.GetInt64(1)}; digest: {digest}");
            }
            await transaction.CommitAsync();
        }
        var directory = Path.Combine(outputRoot, "catalog-audit-" + DateTime.UtcNow.ToString("yyyyMMddTHHmmss", CultureInfo.InvariantCulture) + "-" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(directory);
        await File.WriteAllTextAsync(Path.Combine(directory, "catalog-audit.csv"), Csv(rows), new UTF8Encoding(true));
        await File.WriteAllTextAsync(Path.Combine(directory, "catalog-audit.md"), Markdown(rows, metadata), new UTF8Encoding(false));
        Console.WriteLine(NutritionJson.Write(new { ok = true, output = directory, recipes = rows.Count, eligible = rows.Count(r => MealConstraintPolicy.ValidRecipe(r.Recipe)) }));
        return 0;
    }

    private static void AddBundle(CatalogBundle bundle, List<AuditRecipe> rows)
    {
        if (!CatalogBundleValidator.Validate(bundle).IsValid) throw new InvalidOperationException("Invalid catalog audit bundle.");
        rows.AddRange(bundle.Recipes.Select(r => new AuditRecipe(bundle.PackageKey, r.Payload)));
    }

    public sealed record AuditRecipe(string Catalog, Recipe Recipe);

    public static string Csv(IReadOnlyList<AuditRecipe> rows)
    {
        var text = new StringBuilder("catalog,recipeVersionId,name,mealType,eligible,AllergenDataComplete,ingredients,allergens,preparationSteps,sourceRecipeNote\r\n");
        foreach (var row in rows.OrderBy(r => r.Recipe.MealType).ThenBy(r => r.Recipe.Name, StringComparer.Ordinal))
        {
            var recipe = row.Recipe;
            var cells = new[] { row.Catalog, recipe.VersionId.ToString(), recipe.Name, recipe.MealType,
                MealConstraintPolicy.ValidRecipe(recipe).ToString(), recipe.AllergenDataComplete.ToString(),
                NutritionJson.Write(recipe.Ingredients), NutritionJson.Write(recipe.Allergens),
                NutritionJson.Write(recipe.PreparationSteps), recipe.SourceRecipeNote ?? "" };
            text.AppendLine(string.Join(",", cells.Select(CsvCell)));
        }
        return text.ToString();
    }

    // Prevent spreadsheet formula execution when the CSV is opened for human review.
    private static string CsvCell(string value)
    {
        if (value.TrimStart().FirstOrDefault() is '=' or '+' or '-' or '@') value = "'" + value;
        return "\"" + value.Replace("\"", "\"\"") + "\"";
    }
    private static string Md(string value) => value.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("|", "&#124;").Replace("\r", "").Replace("\n", "<br>");

    public static string Markdown(IReadOnlyList<AuditRecipe> rows, IReadOnlyList<string> metadata)
    {
        var text = new StringBuilder("# Audit catalog chỉ đọc\n\n");
        foreach (var item in metadata) text.AppendLine(Md(item) + "\n");
        text.AppendLine("Eligible dùng MealConstraintPolicy.ValidRecipe, chưa áp dụng hồ sơ hay ràng buộc cá nhân. Bảng gồm cả món bị loại để người duyệt thấy AllergenDataComplete=false.\n");
        text.AppendLine("Catalog không có trường sốt/nước dùng riêng: đối chiếu toàn bộ nguyên liệu, bước nấu và ghi chú nguồn bên dưới; không suy ra an toàn từ việc không thấy tên sốt. Đây là bản xuất dữ liệu, chưa phải kết quả duyệt dị nguyên.\n");
        foreach (var row in rows.OrderByDescending(r => MealConstraintPolicy.ValidRecipe(r.Recipe)).ThenBy(r => r.Recipe.Name, StringComparer.Ordinal))
        {
            var r = row.Recipe;
            text.AppendLine($"## {Md(r.Name)}\n\nCatalog: {Md(row.Catalog)}; version: {r.VersionId}; bữa: {Md(r.MealType)}\n");
            text.AppendLine($"Eligible: {MealConstraintPolicy.ValidRecipe(r)}; AllergenDataComplete: {r.AllergenDataComplete}\n");
            text.AppendLine("Nhãn dị nguyên: " + Md(string.Join(", ", r.Allergens ?? [])) + "\n");
            text.AppendLine("| Nguyên liệu (gồm sốt/nước dùng nếu đã khai báo) | Mã | Lượng | Đơn vị | Basis |\n| --- | --- | --- | --- | --- |");
            foreach (var i in r.Ingredients ?? []) text.AppendLine($"| {Md(i.Name)} | {Md(i.Code)} | {i.Amount.ToString(CultureInfo.InvariantCulture)} | {Md(i.Unit)} | {Md(i.Basis)} |");
            text.AppendLine("\nBước nấu: " + Md(string.Join("; ", r.PreparationSteps ?? [])) + "\n");
            text.AppendLine("Ghi chú nguồn: " + Md(r.SourceRecipeNote ?? "") + "\n");
        }
        return text.ToString();
    }
}
