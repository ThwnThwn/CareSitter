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
            .RequireAuthorization();

        group.MapPost("/upload", UploadImage)
            .DisableAntiforgery()
            .WithSummary("Upload ảnh lên Cloudinary");
    }

    private static async Task<IResult> UploadImage(
        [AsParameters] UploadImageRequest request,
        IMediaService mediaService,
        ICurrentUser currentUser,
        CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId)
            return Results.Unauthorized();

        var file = request.File;
        if (file == null || file.Length == 0)
            return Results.BadRequest(new { error = "File is empty or missing." });

        if (!file.ContentType.StartsWith("image/"))
            return Results.BadRequest(new { error = "Only image files are allowed." });

        using var stream = file.OpenReadStream();
        var targetFolder = string.IsNullOrWhiteSpace(request.Folder) ? "general" : request.Folder;
        targetFolder = $"{targetFolder}/{userId}";

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
    public string? Folder { get; set; }
}
