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
}
