using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application;
using CareSitter.Modules.People.Domain;
using CareSitter.Modules.People.Infrastructure;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System.Reflection;
using FluentValidation;

namespace CareSitter.Modules.People;

public sealed class PeopleModule : IModule
{
    public string Name => "People";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<PeopleDbContext>(options =>
            options.UseNpgsql(
                configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.UseNetTopologySuite()
                    .MigrationsHistoryTable("__ef_migrations", PeopleDbContext.SchemaName)));
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<PeopleModule>());
        services.AddValidatorsFromAssemblyContaining<PeopleModule>();
        services.AddScoped<IPeopleRepository, PeopleRepository>();
        services.AddScoped<IPeopleReadStore, PeopleReadStore>();
        services.AddScoped<IPeopleLookupService, PeopleLookupService>();
        services.AddScoped<IMatchingCaregiverReader, MatchingCaregiverReader>();
        services.AddScoped<ICaregiverRegistrationService, CaregiverRegistrationService>();
        services.AddScoped<IAdminPeopleReader, AdminPeopleReader>();

        // Đăng ký Controllers nằm trong assembly của People module
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(PeopleModule))!);
    }

    // Controllers tự được map qua app.MapControllers() ở Program.cs
    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
