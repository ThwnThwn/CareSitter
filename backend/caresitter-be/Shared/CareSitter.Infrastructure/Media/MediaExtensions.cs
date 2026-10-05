using CareSitter.Contracts.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Media;

public static class MediaExtensions
{
    public static IServiceCollection AddCloudinaryMediaService(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<CloudinarySettings>(configuration.GetSection("Cloudinary"));
        services.AddDataProtection();
        services.AddScoped<IMediaService, CloudinaryMediaService>();
        services.AddScoped<IKycMediaService, KycMediaService>();
        services.AddHttpClient<IKycImageGateway, CloudinaryKycGateway>(client =>
            client.Timeout = TimeSpan.FromSeconds(30))
            .RemoveAllLoggers()
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        return services;
    }
}
