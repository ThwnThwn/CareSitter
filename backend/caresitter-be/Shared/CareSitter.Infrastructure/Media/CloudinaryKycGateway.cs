using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using CloudinaryDotNet;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Options;
using Error = CareSitter.SharedKernel.Results.Error;

namespace CareSitter.Infrastructure.Media;

public sealed record KycProviderUpload(string ObjectKey, string Format, string DeliveryType,
    string ResourceType, long SizeBytes);

public interface IKycImageGateway
{
    Task<Result<KycProviderUpload>> UploadAsync(Stream stream, string objectKey, CancellationToken ct);
    Task<Result<KycImageContent>> DownloadAsync(KycMediaAsset asset, CancellationToken ct);
}

/// <summary>Never returns a provider URL to the client. No client-supplied URL is fetched.</summary>
public sealed class CloudinaryKycGateway(HttpClient http, IOptions<CloudinarySettings> options,
    IClock clock) : IKycImageGateway
{
    private Cloudinary CreateClient()
    {
        var settings = options.Value;
        var cloudinary = new Cloudinary(new Account(settings.CloudName, settings.ApiKey, settings.ApiSecret));
        cloudinary.Api.Secure = true;
        return cloudinary;
    }

    public static ImageUploadParams CreateUploadParameters(Stream stream, string objectKey) => new()
    {
        File = new FileDescription("kyc-image", stream),
        PublicId = objectKey,
        Type = "authenticated",
        Overwrite = false,
        UseFilename = false,
        UniqueFilename = false
    };

    public async Task<Result<KycProviderUpload>> UploadAsync(Stream stream, string objectKey, CancellationToken ct)
    {
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
            deadline.CancelAfter(TimeSpan.FromSeconds(30));
            var requestCt = deadline.Token;
            var result = await CreateClient().UploadAsync(CreateUploadParameters(stream, objectKey), requestCt);
            if (result.Error != null || result.PublicId != objectKey || result.Type != "authenticated" ||
                result.ResourceType != "image" || result.Format is not ("jpg" or "png" or "webp") ||
                result.Bytes is <= 0 or > KycImageValidation.MaxBytes)
                return Error.Failure("kyc.provider_upload", "Không thể lưu ảnh KYC an toàn lúc này.");
            return new KycProviderUpload(result.PublicId, result.Format, result.Type, result.ResourceType, result.Bytes);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch
        {
            // SDK errors can contain credentials/URLs. Do not include them in logs or responses.
            return Error.Unavailable("kyc.provider_unavailable", "Không thể lưu ảnh KYC lúc này. Vui lòng thử lại.");
        }
    }

    public string CreateProviderDownloadUrl(KycMediaAsset asset) => CreateClient().DownloadPrivate(
        asset.ObjectKey, attachment: false, format: asset.Format, type: "authenticated",
        expiresAt: clock.UtcNow.AddSeconds(30).ToUnixTimeSeconds(), resourceType: "image");

    public async Task<Result<KycImageContent>> DownloadAsync(KycMediaAsset asset, CancellationToken ct)
    {
        if (!KycMediaPolicy.IsSecure(asset) || asset.CloudName != options.Value.CloudName ||
            !asset.ObjectKey.StartsWith($"CareSitter/Kyc/{asset.OwnerUserId:D}/", StringComparison.Ordinal))
            return Error.NotFound("kyc.media_not_found", "Không tìm thấy tài liệu KYC an toàn.");
        try
        {
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(ct);
            deadline.CancelAfter(TimeSpan.FromSeconds(30));
            var requestCt = deadline.Token;
            var url = new Uri(CreateProviderDownloadUrl(asset));
            if (url.Scheme != "https" || url.Host != "api.cloudinary.com" || !url.IsDefaultPort)
                return Error.Unavailable("kyc.provider_endpoint", "Không thể đọc ảnh KYC lúc này.");
            using var response = await http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, requestCt);
            var mime = asset.Format == "jpg" ? "image/jpeg" : $"image/{asset.Format}";
            if (!response.IsSuccessStatusCode || response.Content.Headers.ContentType?.MediaType != mime ||
                response.Content.Headers.ContentLength > KycImageValidation.MaxBytes)
                return Error.Unavailable("kyc.provider_download", "Không thể đọc ảnh KYC lúc này.");
            await using var stream = await response.Content.ReadAsStreamAsync(requestCt);
            using var buffer = new MemoryStream();
            var chunk = new byte[8192];
            int read;
            while ((read = await stream.ReadAsync(chunk, requestCt)) > 0)
            {
                if (buffer.Length + read > KycImageValidation.MaxBytes)
                    return Error.Unavailable("kyc.provider_download", "Ảnh KYC không hợp lệ.");
                buffer.Write(chunk, 0, read);
            }
            var bytes = buffer.ToArray();
            if (!KycImageValidation.HasSignature(bytes, asset.Format))
                return Error.Unavailable("kyc.provider_download", "Ảnh KYC không hợp lệ.");
            return new KycImageContent(bytes, mime);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch
        {
            return Error.Unavailable("kyc.provider_unavailable", "Không thể đọc ảnh KYC lúc này. Vui lòng thử lại.");
        }
    }
}

public static class KycImageValidation
{
    public const int MaxBytes = 10 * 1024 * 1024;
    public static bool HasSignature(byte[] bytes, string format) => format switch
    {
        "jpg" => bytes.Length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff,
        "png" => bytes.Length >= 8 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }),
        "webp" => bytes.Length >= 12 && bytes.AsSpan(0, 4).SequenceEqual("RIFF"u8) && bytes.AsSpan(8, 4).SequenceEqual("WEBP"u8),
        _ => false
    };
}
