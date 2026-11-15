namespace CareSitter.Modules.Catalog.Domain;

public sealed class ReportUpload
{
    private ReportUpload() { }
    public Guid Id { get; private set; }
    public Guid OwnerUserId { get; private set; }
    public Guid BookingId { get; private set; }
    public Guid IdempotencyKey { get; private set; }
    public string Checksum { get; private set; } = "";
    public long SizeBytes { get; private set; }
    public string CloudName { get; private set; } = "";
    public string StorageProvider { get; private set; } = "CLOUDINARY";
    public string ObjectKey { get; private set; } = "";
    public string Status { get; private set; } = "PENDING";
    public Guid LeaseToken { get; private set; }
    public DateTimeOffset LeaseUntil { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }

    public static ReportUpload Create(Guid owner, Guid booking, Guid key, string checksum,
        long bytes, string cloud, DateTimeOffset now, string storageProvider = "CLOUDINARY")
    {
        var id = Guid.NewGuid();
        var report = new ReportUpload { Id = id, OwnerUserId = owner, BookingId = booking,
            IdempotencyKey = key, Checksum = checksum, SizeBytes = bytes, CloudName = cloud,
            StorageProvider = storageProvider,
            ObjectKey = storageProvider == "FIREBASE"
                ? $"reports/{owner:D}/{id:N}.pdf"
                : $"CareSitter/Reports/{owner:D}/{id:N}.pdf", CreatedAt = now };
        report.Claim(now);
        return report;
    }
    public void Claim(DateTimeOffset now) { LeaseToken = Guid.NewGuid(); LeaseUntil = now.AddSeconds(90); }
    public void Complete() { Status = "COMPLETED"; }
}
