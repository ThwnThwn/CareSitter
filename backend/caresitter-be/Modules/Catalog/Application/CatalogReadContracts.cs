using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Catalog.Application;

public sealed record ServiceCatalogResponse(
    Guid Id,
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool AllowAdHocTasks,
    long BaseHourlyPrice,
    decimal PlatformFeePercent);

public sealed record PricingRuleResponse(
    Guid Id,
    Guid ServiceTypeId,
    string Name,
    long BaseHourlyPrice,
    decimal NightMultiplier,
    decimal HolidayMultiplier,
    decimal PlatformFeePercent,
    int DisputeWindowHours,
    DateTimeOffset EffectiveFrom,
    DateTimeOffset? EffectiveTo,
    bool IsActive);

public sealed record AdminServiceResponse(
    Guid Id,
    string Code,
    string Name,
    string? Description,
    int DefaultDurationMinutes,
    bool IsActive,
    bool AllowAdHocTasks,
    IReadOnlyList<PricingRuleResponse> PricingRules);

public interface ICatalogReadStore
{
    Task<IReadOnlyList<ServiceCatalogResponse>> ListActiveServicesAsync(
        DateTimeOffset now, CancellationToken ct = default);

    Task<ServiceCatalogResponse?> GetActiveServiceAsync(
        Guid serviceId, DateTimeOffset now, CancellationToken ct = default);

    Task<IReadOnlyList<AddressResponse>> ListOwnedAddressesAsync(
        Guid ownerUserId, CancellationToken ct = default);

    Task<AddressResponse?> GetOwnedAddressAsync(
        Guid addressId, Guid ownerUserId, CancellationToken ct = default);

    Task<IReadOnlyList<AdminServiceResponse>> ListAdminServicesAsync(
        CancellationToken ct = default);
}

public sealed record ListActiveServicesQuery : IRequest<IReadOnlyList<ServiceCatalogResponse>>;
public sealed record GetActiveServiceQuery(Guid ServiceId) : IRequest<ServiceCatalogResponse?>;
public sealed record ListOwnedAddressesQuery : IRequest<Result<IReadOnlyList<AddressResponse>>>;
public sealed record GetOwnedAddressQuery(Guid AddressId) : IRequest<Result<AddressResponse>>;
public sealed record ListAdminServicesQuery : IRequest<IReadOnlyList<AdminServiceResponse>>;
