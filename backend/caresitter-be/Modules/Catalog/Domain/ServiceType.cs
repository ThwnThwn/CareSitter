using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.Catalog.Domain;

/// <summary>
/// Loai dich vu chăm sóc. Map sang bang service_types. Bang KHONG co created_at/updated_at
/// -> Ignore ca CreatedAt lan UpdatedAt.
/// </summary>
public sealed class ServiceType : Entity
{
    private ServiceType() { } // EF

    private ServiceType(
        Guid id,
        string code,
        string name,
        string? description,
        int defaultDurationMinutes,
        bool isActive) : base(id)
    {
        Code = code;
        Name = name;
        Description = description;
        DefaultDurationMinutes = defaultDurationMinutes;
        IsActive = isActive;
    }

    public string Code { get; private set; } = null!;
    public string Name { get; private set; } = null!;
    public string? Description { get; private set; }
    public int DefaultDurationMinutes { get; private set; }
    public bool IsActive { get; private set; }
    public bool AllowAdHocTasks { get; private set; }

    public void SetAllowAdHocTasks(bool allowAdHocTasks) => AllowAdHocTasks = allowAdHocTasks;

    public Result Update(string code, string name, string? description, int defaultDurationMinutes)
    {
        if (string.IsNullOrWhiteSpace(code))
            return Error.Validation("service_type.code", "Mã dịch vụ là bắt buộc.");
        if (string.IsNullOrWhiteSpace(name))
            return Error.Validation("service_type.name", "Tên dịch vụ là bắt buộc.");
        if (defaultDurationMinutes is < 15 or > 1440)
            return Error.Validation("service_type.default_duration_minutes", "Thời lượng mặc định phải từ 15 đến 1.440 phút.");

        Code = code.Trim().ToUpperInvariant();
        Name = name.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        DefaultDurationMinutes = defaultDurationMinutes;
        return Result.Success();
    }

    public void SetActive(bool isActive) => IsActive = isActive;

    public static Result<ServiceType> Create(
        string code,
        string name,
        string? description = null,
        int defaultDurationMinutes = 60,
        bool isActive = true)
    {
        if (string.IsNullOrWhiteSpace(code))
            return Error.Validation("service_type.code", "code la bat buoc.");
        if (string.IsNullOrWhiteSpace(name))
            return Error.Validation("service_type.name", "name la bat buoc.");
        if (defaultDurationMinutes <= 0)
            return Error.Validation("service_type.default_duration_minutes", "default_duration_minutes phai > 0.");

        return new ServiceType(Guid.NewGuid(), code.Trim().ToUpperInvariant(), name.Trim(),
            string.IsNullOrWhiteSpace(description) ? null : description.Trim(), defaultDurationMinutes, isActive);
    }
}
