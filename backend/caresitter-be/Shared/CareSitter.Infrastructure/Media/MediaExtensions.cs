using CareSitter.Contracts.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace CareSitter.Infrastructure.Media;

public static class MediaExtensions
{
    public static IServiceCollection AddCloudinaryMediaService(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<CloudinarySettings>(configuration.GetSection("Cloudinary"));
        services.AddSingleton<IMediaService, CloudinaryMediaService>();
        return services;
    }
}
