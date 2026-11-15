using System.Reflection;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Promotion.Application;
using CareSitter.Modules.Promotion.Infrastructure;
using CareSitter.SharedKernel.Modules;
using FluentValidation;
using MediatR;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Modules.Promotion;

public sealed class PromotionModule : IModule
{
    public string Name => "Promotion";

    public void RegisterServices(IServiceCollection services, IConfiguration configuration)
    {
        services.AddDbContext<PromotionDbContext>(options =>
            options.UseNpgsql(configuration.GetConnectionString("CareSitter"),
                npgsql => npgsql.MigrationsHistoryTable(
                    "__ef_migrations", PromotionDbContext.SchemaName)));
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssemblyContaining<PromotionModule>());
        services.AddValidatorsFromAssemblyContaining<PromotionModule>();
        services.AddTransient<IPipelineBehavior<CreateAdminPromotionCommand, Result<AdminPromotionResponse>>,
            PromotionAdminValidationBehavior<CreateAdminPromotionCommand, AdminPromotionResponse>>();
        services.AddTransient<IPipelineBehavior<UpdateAdminPromotionCommand, Result<AdminPromotionResponse>>,
            PromotionAdminValidationBehavior<UpdateAdminPromotionCommand, AdminPromotionResponse>>();
        services.AddTransient<IPipelineBehavior<SetAdminPromotionActiveCommand, Result<AdminPromotionResponse>>,
            PromotionAdminValidationBehavior<SetAdminPromotionActiveCommand, AdminPromotionResponse>>();
        services.AddTransient<IPipelineBehavior<DeleteAdminPromotionCommand, Result<bool>>,
            PromotionAdminValidationBehavior<DeleteAdminPromotionCommand, bool>>();
        services.AddTransient<IPipelineBehavior<ListAdminPromotionsQuery, Result<AdminPromotionPage>>,
            PromotionAdminValidationBehavior<ListAdminPromotionsQuery, AdminPromotionPage>>();
        services.AddScoped<IPromotionReadStore, PromotionReadStore>();
        services.AddScoped<IPromotionAdminStore, PromotionAdminStore>();
        services.AddScoped<IPromotionService, PromotionApplicationService>();
        services.AddControllers()
            .AddApplicationPart(Assembly.GetAssembly(typeof(PromotionModule))!);
    }

    public void MapEndpoints(IEndpointRouteBuilder endpoints) { }
}
