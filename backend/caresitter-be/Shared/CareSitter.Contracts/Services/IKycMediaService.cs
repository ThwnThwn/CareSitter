using CareSitter.SharedKernel.Results;

namespace CareSitter.Contracts.Services;

public sealed record KycMediaAsset(Guid Id, Guid OwnerUserId, string CloudName,
    string ObjectKey, string Format, string DocumentType, long SizeBytes,
    string DeliveryType = "authenticated");
public sealed record KycImageContent(byte[] Bytes, string ContentType);
public sealed record KycMediaReadAccess(string Url, string Ticket, int ExpiresInSeconds);

public interface IKycMediaStore
{
    Task AddAsync(KycMediaAsset asset, CancellationToken ct);
    Task<KycMediaAsset?> FindAsync(Guid id, CancellationToken ct);
}

/// <summary>People owns the link between a submitted profile and its documents.</summary>
public interface IKycDocumentAccess
{
    Task<bool> IsSubmittedAsync(Guid mediaId, Guid ownerUserId, CancellationToken ct);
}

public interface IKycMediaService
{
    Task<Result<Guid>> UploadAsync(Stream stream, string fileName, string documentType,
        CancellationToken ct);
    Task<Result<KycMediaReadAccess>> CreateReadUrlAsync(Guid mediaId, TimeSpan ttl, CancellationToken ct);
    Task<Result<KycImageContent>> ReadAsync(Guid mediaId, string ticket, CancellationToken ct);
}

public static class KycMediaPolicy
{
    private static readonly string[] CertificateTypes =
        ["NURSING_CERT", "HEALTH_CERT", "CRIMINAL_RECORD", "OTHER"];

    public static bool IsDocumentType(string value) =>
        value is "CCCD_FRONT" or "CCCD_BACK" || CertificateTypes.Contains(value);

    public static bool IsSecure(KycMediaAsset asset) =>
        asset.DeliveryType == "authenticated" && asset.OwnerUserId != Guid.Empty &&
        asset.Format is "jpg" or "png" or "webp" && IsDocumentType(asset.DocumentType);

    public static async Task<Result> ValidateSubmissionAsync(IKycMediaStore store,
        Guid owner, Guid? front, Guid? back, IReadOnlyCollection<Guid> certificates,
        CancellationToken ct)
    {
        if (front is null || back is null || front == Guid.Empty || back == Guid.Empty ||
            certificates.Count > 10 || certificates.Contains(Guid.Empty))
            return Error.Validation("kyc.media_required", "Cần tải lên đủ hai mặt CCCD bằng media an toàn.");
        var ids = new[] { front.Value, back.Value }.Concat(certificates).ToArray();
        if (ids.Distinct().Count() != ids.Length)
            return Error.Validation("kyc.media_duplicate", "Không dùng cùng một ảnh cho nhiều tài liệu KYC.");
        for (var i = 0; i < ids.Length; i++)
        {
            var asset = await store.FindAsync(ids[i], ct);
            if (asset is null || asset.OwnerUserId != owner || !IsSecure(asset) ||
                (i == 0 ? asset.DocumentType != "CCCD_FRONT" :
                 i == 1 ? asset.DocumentType != "CCCD_BACK" :
                 !CertificateTypes.Contains(asset.DocumentType)))
                return Error.Validation("kyc.media_invalid", "Tài liệu KYC không hợp lệ, sai loại hoặc không thuộc tài khoản này.");
        }
        return Result.Success();
    }
}
