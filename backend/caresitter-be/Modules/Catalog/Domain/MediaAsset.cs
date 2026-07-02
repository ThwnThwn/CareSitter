using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Domain;

/// <summary>
/// Tai nguyen media (anh, tai lieu KYC, chung chi...). Map sang bang media_assets.
/// Gom ca caregiver_documents (KYC). Bang chi co created_at, KHONG co updated_at.
/// </summary>
public sealed class MediaAsset : Entity
{
    private MediaAsset() { } // EF

    private MediaAsset(
        Guid id,
        string storageProvider,
        string bucket,
        string objectKey,
        string mediaType,
        Guid? ownerUserId,
        Guid? bookingId,
        string? url,
        string? mimeType,
        long? sizeBytes,
        string? checksum,
        bool isSensitive,
        string? exifMetadata,
        string? documentType) : base(id)
    {
        StorageProvider = storageProvider;
        Bucket = bucket;
        ObjectKey = objectKey;
        MediaType = mediaType;
        OwnerUserId = ownerUserId;
        BookingId = bookingId;
        Url = url;
        MimeType = mimeType;
        SizeBytes = sizeBytes;
        Checksum = checksum;
        IsSensitive = isSensitive;
        ExifMetadata = exifMetadata;
        DocumentType = documentType;
    }

    public Guid? OwnerUserId { get; private set; }
    public Guid? BookingId { get; private set; }

    /// <summary>Allowed: 'S3', 'CLOUDINARY'.</summary>
    public string StorageProvider { get; private set; } = null!;
    public string Bucket { get; private set; } = null!;
    public string ObjectKey { get; private set; } = null!;
    public string? Url { get; private set; }
    public string? MimeType { get; private set; }
    public long? SizeBytes { get; private set; }
    public string? Checksum { get; private set; }

    /// <summary>Allowed: 'PHOTO', 'DOCUMENT', 'CERTIFICATE', 'AVATAR', 'MEDICAL_FILE'.</summary>
    public string MediaType { get; private set; } = null!;
    public bool IsSensitive { get; private set; }

    /// <summary>jsonb.</summary>
    public string? ExifMetadata { get; private set; }

    /// <summary>Allowed: 'CCCD_FRONT', 'CCCD_BACK', 'PORTRAIT', 'NURSING_CERT', 'HEALTH_CERT', 'CRIMINAL_RECORD', 'OTHER'.</summary>
    public string? DocumentType { get; private set; }

    /// <summary>Allowed: 'PENDING', 'APPROVED', 'REJECTED'.</summary>
    public string? VerificationStatus { get; private set; }
    public string? RejectedReason { get; private set; }
    public Guid? ReviewedByAdminId { get; private set; }
    public DateTimeOffset? ReviewedAt { get; private set; }

    public static Result<MediaAsset> Create(
        string storageProvider,
        string bucket,
        string objectKey,
        string mediaType,
        Guid? ownerUserId = null,
        Guid? bookingId = null,
        string? url = null,
        string? mimeType = null,
        long? sizeBytes = null,
        string? checksum = null,
        bool isSensitive = false,
        string? exifMetadata = null,
        string? documentType = null)
    {
        if (string.IsNullOrWhiteSpace(storageProvider))
            return Error.Validation("media_asset.storage_provider", "storage_provider la bat buoc.");
        if (string.IsNullOrWhiteSpace(bucket))
            return Error.Validation("media_asset.bucket", "bucket la bat buoc.");
        if (string.IsNullOrWhiteSpace(objectKey))
            return Error.Validation("media_asset.object_key", "object_key la bat buoc.");
        if (string.IsNullOrWhiteSpace(mediaType))
            return Error.Validation("media_asset.media_type", "media_type la bat buoc.");
        if (sizeBytes is < 0)
            return Error.Validation("media_asset.size_bytes", "size_bytes khong duoc am.");

        return new MediaAsset(Guid.NewGuid(), storageProvider, bucket, objectKey, mediaType,
            ownerUserId, bookingId, url, mimeType, sizeBytes, checksum, isSensitive, exifMetadata, documentType);
    }
}
