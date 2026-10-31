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
        string? imageUrl,
        int defaultDurationMinutes,
        bool isActive) : base(id)
    {
        Code = code;
        Name = name;
        Description = description;
        ImageUrl = imageUrl;
        DefaultDurationMinutes = defaultDurationMinutes;
        IsActive = isActive;
    }

    public string Code { get; private set; } = null!;
    public string Name { get; private set; } = null!;
    public string? Description { get; private set; }
    public string? ImageUrl { get; private set; }
    public int DefaultDurationMinutes { get; private set; }
    public bool IsActive { get; private set; }
    public bool AllowAdHocTasks { get; private set; }

    public void SetAllowAdHocTasks(bool allowAdHocTasks) => AllowAdHocTasks = allowAdHocTasks;

    public Result Update(string code, string name, string? description, int defaultDurationMinutes) =>
        Update(code, name, description, ImageUrl, defaultDurationMinutes);

    public Result Update(string code, string name, string? description, string? imageUrl,
        int defaultDurationMinutes)
    {
        if (string.IsNullOrWhiteSpace(code))
            return Error.Validation("service_type.code", "Mã dịch vụ là bắt buộc.");
        if (code.Trim().Length > 100)
            return Error.Validation("service_type.code", "Mã dịch vụ tối đa 100 ký tự.");
        if (string.IsNullOrWhiteSpace(name))
            return Error.Validation("service_type.name", "Tên dịch vụ là bắt buộc.");
        if (name.Trim().Length > 255)
            return Error.Validation("service_type.name", "Tên dịch vụ tối đa 255 ký tự.");
        if (defaultDurationMinutes is < 15 or > 1440)
            return Error.Validation("service_type.default_duration_minutes", "Thời lượng mặc định phải từ 15 đến 1.440 phút.");

        var normalizedImageUrl = string.IsNullOrWhiteSpace(imageUrl) ? null : imageUrl.Trim();
        if (normalizedImageUrl is not null &&
            (normalizedImageUrl.Length > 2048 ||
             !Uri.TryCreate(normalizedImageUrl, UriKind.Absolute, out var imageUri) ||
             imageUri.Scheme is not ("http" or "https")))
            return Error.Validation("service_type.image_url", "URL ảnh dịch vụ không hợp lệ.");

        Code = code.Trim().ToUpperInvariant();
        Name = name.Trim();
        Description = string.IsNullOrWhiteSpace(description) ? null : description.Trim();
        ImageUrl = normalizedImageUrl;
        DefaultDurationMinutes = defaultDurationMinutes;
        return Result.Success();
    }

    public void SetActive(bool isActive) => IsActive = isActive;

    public static Result<ServiceType> Create(
        string code,
        string name,
        string? description = null,
        int defaultDurationMinutes = 60,
        bool isActive = true,
        string? imageUrl = null)
    {
        var service = new ServiceType(Guid.NewGuid(), string.Empty, string.Empty,
            null, null, 60, isActive);
        var validation = service.Update(code, name, description, imageUrl, defaultDurationMinutes);
        return validation.IsFailure ? validation.Error : service;
    }
}
