using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.SharedKernel.Modules;

/// <summary>
/// Hop dong cho 1 module. ApiHost quet va goi tat ca IModule -> host khong biet chi tiet module.
/// </summary>
public interface IModule
{
    string Name { get; }

    /// <summary>Dang ky DI rieng cua module (DbContext, handlers, services...).</summary>
    void RegisterServices(IServiceCollection services, IConfiguration configuration);

    /// <summary>Map endpoint cua module vao route builder chung.</summary>
    void MapEndpoints(IEndpointRouteBuilder endpoints);
}
