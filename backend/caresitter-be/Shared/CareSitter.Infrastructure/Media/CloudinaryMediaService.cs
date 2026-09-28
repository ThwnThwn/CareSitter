using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Options;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using DomainError = CareSitter.SharedKernel.Results.Error;

namespace CareSitter.Infrastructure.Media;

internal sealed class CloudinaryMediaService : IMediaService
{
    private readonly Cloudinary _cloudinary;
    private readonly ILogger<CloudinaryMediaService> _logger;

    public CloudinaryMediaService(
        IOptions<CloudinarySettings> options,
        ILogger<CloudinaryMediaService> logger)
    {
        _logger = logger;
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
        if (fileStream == null || !fileStream.CanRead)
        {
            return CareSitter.SharedKernel.Results.Error.Validation("upload.empty", "File stream is empty.");
        }

        if (!fileStream.CanSeek || fileStream.Length == 0)
            return DomainError.Validation("upload.invalid_stream", "Tệp tải lên không hợp lệ.");
        if (fileStream.Length > 10 * 1024 * 1024)
            return DomainError.Validation("upload.too_large", "Ảnh không được vượt quá 10 MB.");

        var safeFileName = Path.GetFileName(fileName);
        var extension = Path.GetExtension(safeFileName).ToLowerInvariant();
        if (extension is not (".jpg" or ".jpeg" or ".png" or ".webp"))
            return DomainError.Validation("upload.invalid_extension", "Chỉ chấp nhận ảnh JPG, PNG hoặc WEBP.");

        var header = new byte[12];
        fileStream.Position = 0;
        var read = await fileStream.ReadAsync(header.AsMemory(0, header.Length), ct);
        fileStream.Position = 0;
        if (!HasAllowedImageSignature(header, read))
            return DomainError.Validation("upload.invalid_content", "Nội dung tệp không phải ảnh hợp lệ.");

        var uploadParams = new ImageUploadParams
        {
            File = new FileDescription(safeFileName, fileStream),
            Folder = folder,
            // Optionally, set transformation, tags, etc.
            // Transformation = new Transformation().Width(1000).Height(1000).Crop("limit")
        };

        try
        {
            var uploadResult = await _cloudinary.UploadAsync(uploadParams, ct);

            if (uploadResult.Error != null)
            {
                _logger.LogWarning("Cloudinary rejected an image upload.");
                return DomainError.Failure("upload.failed", "Không thể lưu ảnh lúc này.");
            }

            return Result.Success(uploadResult.SecureUrl.ToString());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Cloudinary image upload failed.");
            return DomainError.Failure("upload.exception", "Không thể lưu ảnh lúc này.");
        }
    }

    private static bool HasAllowedImageSignature(byte[] header, int length)
    {
        var jpeg = length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF;
        var png = length >= 8 && header.AsSpan(0, 8).SequenceEqual(
            new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });
        var webp = length >= 12 &&
            header.AsSpan(0, 4).SequenceEqual("RIFF"u8) &&
            header.AsSpan(8, 4).SequenceEqual("WEBP"u8);
        return jpeg || png || webp;
    }
}
