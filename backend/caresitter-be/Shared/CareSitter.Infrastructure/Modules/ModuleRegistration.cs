using System.Reflection;
using CareSitter.SharedKernel.Modules;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Modules;

/// <summary>
/// Quet va dang ky tat ca IModule. ApiHost goi AddModules() roi MapModuleEndpoints().
/// </summary>
public static class ModuleRegistration
{
    public static IServiceCollection AddModules(
        this IServiceCollection services,
        IConfiguration configuration,
        params Assembly[] moduleAssemblies)
    {
        var modules = DiscoverModules(moduleAssemblies);

        foreach (var module in modules)
        {
            module.RegisterServices(services, configuration);
            services.AddSingleton(module);
        }

        return services;
    }

    public static IEndpointRouteBuilder MapModuleEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var modules = endpoints.ServiceProvider.GetServices<IModule>();
        foreach (var module in modules)
            module.MapEndpoints(endpoints);

        return endpoints;
    }

    private static IReadOnlyList<IModule> DiscoverModules(Assembly[] assemblies)
    {
        return assemblies
            .SelectMany(a => a.GetTypes())
            .Where(t => typeof(IModule).IsAssignableFrom(t)
                        && t is { IsAbstract: false, IsInterface: false })
            .Select(t => (IModule)Activator.CreateInstance(t)!)
            .OrderBy(m => m.Name)
            .ToList();
    }
}
