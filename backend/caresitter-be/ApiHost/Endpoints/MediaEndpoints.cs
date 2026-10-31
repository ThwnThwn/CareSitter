using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

namespace CareSitter.ApiHost.Endpoints;

internal static class MediaEndpoints
{
    public static void Map(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/media")
            .WithTags("Media")
            .RequireAuthorization()
            .RequireRateLimiting("media-read");

        group.MapPost("/upload", UploadImage)
            .DisableAntiforgery()
            .RequireAuthorization()
            .WithSummary("Upload ảnh lên Cloudinary");
        group.MapPost("/{id:guid}/access", async (Guid id, IKycMediaService media, HttpContext context, CancellationToken ct) =>
        {
            SetPrivateHeaders(context);
            var result = await media.CreateReadUrlAsync(id, TimeSpan.FromMinutes(2), ct);
            return result.IsSuccess ? Results.Ok(result.Value) : Failure(result.Error);
        });
        group.MapGet("/{id:guid}/content", async (Guid id, [FromHeader(Name = "X-Kyc-Read-Ticket")] string? ticket, IKycMediaService media, HttpContext context, CancellationToken ct) =>
        {
            SetPrivateHeaders(context);
            var result = await media.ReadAsync(id, ticket ?? "", ct);
            return result.IsSuccess ? Results.Bytes(result.Value.Bytes, result.Value.ContentType) : Failure(result.Error);
        });
    }

    private static void SetPrivateHeaders(HttpContext context)
    {
        context.Response.Headers.CacheControl = "no-store, private";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers["X-Content-Type-Options"] = "nosniff";
        context.Response.Headers["Content-Security-Policy"] = "default-src 'none'; sandbox";
    }

    private static IResult Failure(Error error) => Results.Problem(title: error.Code, detail: error.Message,
        statusCode: error.Type switch { ErrorType.Validation => 400, ErrorType.Forbidden => 403,
            ErrorType.NotFound => 404, ErrorType.Unavailable => 503, _ => 500 });

    private static async Task<IResult> UploadImage(
        [AsParameters] UploadImageRequest request,
        IMediaService mediaService,
        IKycMediaService kycMedia,
        ICurrentUser currentUser,
        HttpContext context,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Results.Unauthorized();

        var file = request.File;
        if (file == null || file.Length == 0)
            return Results.BadRequest(new { error = "File is empty or missing." });

        if (file.Length > 10 * 1024 * 1024)
            return Results.BadRequest(new { error = "Image must not exceed 10 MB." });

        if (file.ContentType is not ("image/jpeg" or "image/png" or "image/webp"))
            return Results.BadRequest(new { error = "Only JPEG, PNG or WEBP images are allowed." });

        var folder = request.Folder?.Trim().ToLowerInvariant();
        if (request.DocumentType != null && folder != "kyc")
            return Results.BadRequest(new { error = "KYC document uploads must use folder=kyc." });
        if (folder == "kyc" && !currentUser.IsInRole("CAREGIVER"))
            return Results.Forbid();
        if (folder is "checklist" or "checklists" && !currentUser.IsInRole("CAREGIVER"))
            return Results.Forbid();
        if (folder is "beneficiary" or "beneficiaries" && !currentUser.IsInRole("CUSTOMER"))
            return Results.Forbid();
        if (folder is "catalog" or "service" or "services" && !currentUser.IsInRole("ADMIN"))
            return Results.Forbid();

        using var stream = file.OpenReadStream();
        if (folder == "kyc")
        {
            SetPrivateHeaders(context);
            var uploaded = await kycMedia.UploadAsync(stream, file.FileName,
                request.DocumentType?.Trim().ToUpperInvariant() ?? "", ct);
            return uploaded.IsSuccess ? Results.Ok(new { mediaId = uploaded.Value }) : Failure(uploaded.Error);
        }
        var targetFolder = folder switch
        {
            "avatars" or "avatar" => $"CareSitter/Avatars/{userId}",
            "checklist" or "checklists" => $"CareSitter/Checklist/{userId}",
            "beneficiary" or "beneficiaries" => $"CareSitter/Beneficiaries/{userId}",
            "support" => $"CareSitter/Support/{userId}",
            "catalog" or "service" or "services" => "CareSitter/Catalog",
            _ => $"CareSitter/Uploads/{userId}",
        };

        var result = await mediaService.UploadImageAsync(stream, file.FileName, targetFolder, ct);

        if (result.IsFailure)
        {
            return Results.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: 500);
        }

        return Results.Ok(new { url = result.Value });
    }
}

/// <summary>Request model cho upload ảnh — dùng [AsParameters] để Swashbuckle generate đúng multipart/form-data.</summary>
public sealed class UploadImageRequest
{
    /// <summary>File ảnh cần upload (jpeg, png, webp...)</summary>
    public IFormFile File { get; set; } = null!;

    /// <summary>Thư mục lưu trữ trên Cloudinary (tuỳ chọn, mặc định: "general")</summary>
    [FromForm]
    public string? Folder { get; set; }
    [FromForm]
    public string? DocumentType { get; set; }
}
