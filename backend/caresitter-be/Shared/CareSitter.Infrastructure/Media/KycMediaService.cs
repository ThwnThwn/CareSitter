using System.Security.Cryptography;
using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.Extensions.Options;

namespace CareSitter.Infrastructure.Media;

public sealed class KycMediaService(IKycImageGateway gateway, IKycMediaStore store,
    IKycDocumentAccess documentAccess, ICurrentUser currentUser, IClock clock,
    IDataProtectionProvider protection, IOptions<CloudinarySettings> options,
    IAuditLogger audit) : IKycMediaService
{
    public static readonly TimeSpan MaximumTtl = TimeSpan.FromMinutes(5);
    private readonly IDataProtector protector = protection.CreateProtector("CareSitter.KycRead.v1");
    private sealed record Ticket(Guid MediaId, Guid UserId, long ExpiresAt);
    private static Error Missing() => Error.NotFound("kyc.media_not_found", "Không tìm thấy tài liệu KYC hoặc bạn không có quyền xem.");

    public async Task<Result<Guid>> UploadAsync(Stream stream, string fileName, string documentType, CancellationToken ct)
    {
        if (currentUser.UserId is not { } owner || !currentUser.IsInRole("CAREGIVER"))
            return Error.Forbidden("kyc.upload_forbidden", "Chỉ caregiver được tải lên hồ sơ KYC của mình.");
        if (!KycMediaPolicy.IsDocumentType(documentType))
            return Error.Validation("kyc.document_type", "Loại tài liệu KYC không hợp lệ.");
        var format = Path.GetExtension(Path.GetFileName(fileName)).ToLowerInvariant() switch
        { ".jpg" or ".jpeg" => "jpg", ".png" => "png", ".webp" => "webp", _ => "" };
        if (!stream.CanRead || !stream.CanSeek || stream.Length is <= 0 or > KycImageValidation.MaxBytes)
            return Error.Validation("kyc.image_size", "Ảnh KYC phải có dữ liệu và không vượt quá 10 MB.");
        var header = new byte[12];
        stream.Position = 0;
        var read = (int)Math.Min(header.Length, stream.Length);
        await stream.ReadExactlyAsync(header.AsMemory(0, read), ct);
        stream.Position = 0;
        if (!KycImageValidation.HasSignature(header[..read], format))
            return Error.Validation("kyc.image_format", "Chỉ nhận ảnh JPG, PNG hoặc WEBP có nội dung hợp lệ.");
        var id = Guid.NewGuid();
        var objectKey = $"CareSitter/Kyc/{owner:D}/{id:N}";
        var uploaded = await gateway.UploadAsync(stream, objectKey, ct);
        if (uploaded.IsFailure) return uploaded.Error;
        var result = uploaded.Value;
        if (result.ObjectKey != objectKey || result.DeliveryType != "authenticated" ||
            result.ResourceType != "image" || result.Format != format || result.SizeBytes is <= 0 or > KycImageValidation.MaxBytes)
            return Error.Unavailable("kyc.provider_contract", "Không thể xác nhận ảnh KYC an toàn.");
        await store.AddAsync(new KycMediaAsset(id, owner, options.Value.CloudName, objectKey,
            format, documentType, result.SizeBytes), ct);
        await audit.WriteAsync("KYC_MEDIA_UPLOADED", "MediaAsset", id, null, new { documentType }, ct);
        return id;
    }

    private async Task<KycMediaAsset?> AuthorizedAssetAsync(Guid id, CancellationToken ct)
    {
        if (currentUser.UserId is not { } actor) return null;
        var asset = await store.FindAsync(id, ct);
        if (asset is null || !KycMediaPolicy.IsSecure(asset)) return null;
        if (currentUser.IsInRole("CAREGIVER") && asset.OwnerUserId == actor) return asset;
        if (currentUser.IsInRole("ADMIN") && await documentAccess.IsSubmittedAsync(id, asset.OwnerUserId, ct)) return asset;
        return null;
    }

    public async Task<Result<KycMediaReadAccess>> CreateReadUrlAsync(Guid mediaId, TimeSpan ttl, CancellationToken ct)
    {
        if (ttl <= TimeSpan.Zero || ttl > MaximumTtl)
            return Error.Validation("kyc.ttl", "Thời hạn xem ảnh phải lớn hơn 0 và tối đa 5 phút.");
        if (await AuthorizedAssetAsync(mediaId, ct) is null) return Missing();
        var ticket = protector.Protect(JsonSerializer.Serialize(new Ticket(mediaId,
            currentUser.UserId!.Value, clock.UtcNow.Add(ttl).ToUnixTimeSeconds())));
        return new KycMediaReadAccess($"/api/v1/media/{mediaId:D}/content", ticket, (int)ttl.TotalSeconds);
    }

    public async Task<Result<KycImageContent>> ReadAsync(Guid mediaId, string ticket, CancellationToken ct)
    {
        Ticket? payload;
        try
        {
            if (string.IsNullOrWhiteSpace(ticket) || ticket.Length > 2048) return Missing();
            payload = JsonSerializer.Deserialize<Ticket>(protector.Unprotect(ticket));
        }
        catch (Exception ex) when (ex is CryptographicException or JsonException or FormatException)
        { return Missing(); }
        if (payload is null || payload.MediaId != mediaId || payload.UserId != currentUser.UserId ||
            payload.ExpiresAt <= clock.UtcNow.ToUnixTimeSeconds()) return Missing();
        var asset = await AuthorizedAssetAsync(mediaId, ct);
        if (asset is null) return Missing();
        // Audit contains IDs/action only, never URL, ticket, CCCD or image bytes.
        await audit.WriteAsync("KYC_MEDIA_READ", "MediaAsset", mediaId, null, null, ct);
        return await gateway.DownloadAsync(asset, ct);
    }
}
