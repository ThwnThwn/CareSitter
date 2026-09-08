using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Options;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace CareSitter.Infrastructure.Media;

internal sealed class CloudinaryMediaService : IMediaService
{
    private readonly Cloudinary _cloudinary;

    public CloudinaryMediaService(IOptions<CloudinarySettings> options)
    {
        var settings = options.Value;
        var account = new Account(
            settings.CloudName,
            settings.ApiKey,
            settings.ApiSecret);
        _cloudinary = new Cloudinary(account);
        _cloudinary.Api.Secure = true;
    }

    public Task<Result<string>> CreateSignedUrlAsync(Guid mediaId, TimeSpan ttl, CancellationToken ct = default)
    {
        // For Cloudinary, usually we store public URLs, or use signed URLs.
        // If needed, can be implemented later.
        return Task.FromResult(Result.Success(string.Empty));
    }

    public async Task<Result<string>> UploadImageAsync(Stream fileStream, string fileName, string folder, CancellationToken ct = default)
    {
        if (fileStream == null || fileStream.Length == 0)
        {
            return CareSitter.SharedKernel.Results.Error.Validation("upload.empty", "File stream is empty.");
        }

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(fileName, fileStream),
            Folder = folder,
            // Optionally, set transformation, tags, etc.
            // Transformation = new Transformation().Width(1000).Height(1000).Crop("limit")
        };

        try
        {
            var uploadResult = await _cloudinary.UploadAsync(uploadParams, ct);

            if (uploadResult.Error != null)
            {
                return CareSitter.SharedKernel.Results.Error.Failure("upload.failed", uploadResult.Error.Message);
            }

            return Result.Success(uploadResult.SecureUrl.ToString());
        }
        catch (Exception ex)
        {
            return CareSitter.SharedKernel.Results.Error.Failure("upload.exception", ex.Message);
        }
    }
}
