namespace CareSitter.Modules.Booking.Domain;

/// <summary>Task mau cua mot goi dich vu. Booking chi doc mau nay de snapshot khi duoc xac nhan.</summary>
public sealed class PackageTaskTemplate
{
    private PackageTaskTemplate() { }

    public Guid Id { get; private set; }
    public Guid ServiceTypeId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? Description { get; private set; }
    public bool IsRequired { get; private set; }
    public bool RequiresPhoto { get; private set; }
    public int SortOrder { get; private set; }
    public bool IsActive { get; private set; }

    public static PackageTaskTemplate Create(Guid serviceTypeId, string name, string? description,
        bool isRequired, bool requiresPhoto, int sortOrder)
    {
        return new PackageTaskTemplate
        {
            Id = Guid.NewGuid(),
            ServiceTypeId = serviceTypeId,
            Name = name.Trim(),
            Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim(),
            IsRequired = isRequired,
            RequiresPhoto = requiresPhoto,
            SortOrder = sortOrder,
            IsActive = true
        };
    }

    public void Update(string name, string? description, bool isRequired, bool requiresPhoto, int sortOrder)
    {
        Name = name.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        IsRequired = isRequired;
        RequiresPhoto = requiresPhoto;
        SortOrder = sortOrder;
    }

    public void SetActive(bool isActive) => IsActive = isActive;
}
