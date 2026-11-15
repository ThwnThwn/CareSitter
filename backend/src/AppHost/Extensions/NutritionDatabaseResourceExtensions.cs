using Aspire.Hosting.ApplicationModel;
using Microsoft.Extensions.Configuration;

namespace CareSitter.AppHost.Extensions;

internal static class NutritionDatabaseResourceExtensions
{
    public static async Task AddNutritionDatabaseAsync(this IDistributedApplicationBuilder builder,
        AppHostSettings settings, IResourceBuilder<ProjectResource> nutrition)
    {
        var configuration = settings.Configuration;
        var connection = configuration.GetConnectionString("Nutrition");
        if (string.IsNullOrWhiteSpace(connection) && configuration.GetValue("NutritionDatabase:UseCareSitterServer", false))
        {
            var coreConnection = configuration.Required("ConnectionStrings:CareSitter");
            var database = configuration["NutritionDatabase:Name"] ?? "nutrition";
            var username = configuration["NutritionDatabase:Username"] ?? "nutrition_app";
            var password = configuration.Required("Parameters:nutrition-runtime-password");
            if (configuration.GetValue("NutritionDatabase:ManageLocalRuntimePassword", false))
                await NutritionDatabaseConfiguration.ConfigureSharedServerRuntimeRoleAsync(coreConnection, database, username, password);
            connection = NutritionDatabaseConfiguration.BuildSharedServerConnection(coreConnection, database, username, password);
        }
        if (!string.IsNullOrWhiteSpace(connection))
        {
            nutrition.WithEnvironment("ConnectionStrings__Nutrition", builder.AddSecret("nutrition-db-connection", connection));
            return;
        }

        var postgres = builder.AddPostgres("nutrition-db", password: builder.AddParameter("nutrition-admin-password", secret: true))
            .WithImageTag("16")
            .WithEnvironment("POSTGRES_DB", "nutrition")
            .WithEnvironment("NUTRITION_DB_APP_PASSWORD", settings.NutritionRuntimePassword)
            .WithBindMount(Path.Combine(settings.RepositoryPath, "backend/init-db/nutrition-service/02-runtime-role.sql"),
                "/runtime-role.sql", isReadOnly: true)
            .WithBindMount(Path.Combine(settings.RepositoryPath, "backend/src/Services/Nutrition/scripts/02-runtime-role.sh"),
                "/docker-entrypoint-initdb.d/02-runtime-role.sh", isReadOnly: true)
            .WithDataVolume(configuration["AppHost:NutritionDataVolume"] ?? "caresitter-apphost-nutrition");

        foreach (var (file, target) in new[]
        {
            ("01-nutrition-workflow.sql", "01-schema.sql"),
            ("03-catalog-governance.sql", "03-catalog-governance.sql"),
            ("04-catalog-nutrient-constraints.sql", "04-catalog-nutrient-constraints.sql"),
            ("05-recipe-source-citations.sql", "05-recipe-source-citations.sql"),
            ("06-catalog-release-evidence.sql", "06-catalog-release-evidence.sql"),
            ("07-catalog-knowledge-review-gate.sql", "07-catalog-knowledge-review-gate.sql"),
            ("08-local-demo-catalog.sql", "08-local-demo-catalog.sql"),
            ("09-knowledge-chunks.sql", "09-knowledge-chunks.sql"),
            ("10-published-catalog-integrity.sql", "10-published-catalog-integrity.sql"),
            ("11-catalog-review-policy.sql", "11-catalog-review-policy.sql"),
            ("12-beneficiary-deletion.sql", "12-beneficiary-deletion.sql")
        })
            postgres.WithBindMount(Path.Combine(settings.RepositoryPath, "backend/init-db/nutrition-service", file),
                $"/docker-entrypoint-initdb.d/{target}", isReadOnly: true);

        var databaseResource = postgres.AddDatabase("nutrition-store", databaseName: "nutrition");
        nutrition.WithEnvironment("ConnectionStrings__Nutrition", ReferenceExpression.Create(
                $"Host={postgres.GetEndpoint("tcp").Property(EndpointProperty.Host)};Port={postgres.GetEndpoint("tcp").Property(EndpointProperty.Port)};Database=nutrition;Username=nutrition_app;Password={settings.NutritionRuntimePassword}"))
            .WaitFor(databaseResource);
    }
}
