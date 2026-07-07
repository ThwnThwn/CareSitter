using Microsoft.OpenApi.Models;

namespace CareSitter.ApiHost.OpenApi;

/// <summary>
/// Extension methods để cấu hình Swagger / OpenAPI cho CareSitter API.
/// </summary>
internal static class SwaggerExtensions
{
    /// <summary>
    /// Đăng ký SwaggerGen với JWT Bearer authentication và XML doc comments.
    /// </summary>
    public static IServiceCollection AddCareSitterSwagger(this IServiceCollection services)
    {
        services.AddSwaggerGen(options =>
        {
            // --- Thông tin API ---
            options.SwaggerDoc("v1", new OpenApiInfo
            {
                Title       = "CareSitter API",
                Version     = "v1",
                Description = "API quản lý dịch vụ chăm sóc người thân CareSitter."
            });

            // --- JWT Bearer security definition ---
            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Name        = "Authorization",
                Type        = SecuritySchemeType.Http,
                Scheme      = "bearer",
                BearerFormat = "JWT",
                In          = ParameterLocation.Header,
                Description = "Nhập JWT token vào đây. Ví dụ: eyJhbGci..."
            });

            // Áp dụng security requirement toàn cục (tất cả endpoint đều hiện khóa)
            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id   = "Bearer"
                        }
                    },
                    Array.Empty<string>()
                }
            });

            // --- XML doc comments từ tất cả assembly được publish vào output ---
            // Bao gồm: ApiHost.xml, CareSitter.Modules.Identity.xml, v.v.
            var xmlFiles = Directory.GetFiles(AppContext.BaseDirectory, "*.xml", SearchOption.TopDirectoryOnly);
            foreach (var xmlFile in xmlFiles)
            {
                options.IncludeXmlComments(xmlFile, includeControllerXmlComments: true);
            }
        });

        return services;
    }

    /// <summary>
    /// Cấu hình Swagger UI với tên và endpoint phù hợp.
    /// </summary>
    public static IApplicationBuilder UseCareSitterSwagger(this IApplicationBuilder app)
    {
        app.UseSwagger();
        app.UseSwaggerUI(ui =>
        {
            ui.SwaggerEndpoint("/swagger/v1/swagger.json", "CareSitter API v1");
            ui.RoutePrefix = "swagger"; // Truy cập tại /swagger
            ui.DocumentTitle = "CareSitter API Docs";

            // Hiện thời gian request/response
            ui.DisplayRequestDuration();

            // Mở rộng tất cả operation mặc định
            ui.DefaultModelsExpandDepth(-1); // Ẩn Schema section phía dưới để gọn hơn
        });

        return app;
    }
}
