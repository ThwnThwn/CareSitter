using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.Catalog.Domain;

/// <summary>
/// Dia chi cham soc (geo-coded). Map sang bang addresses. Co created_at + updated_at
/// (trg_addresses_updated). Cot latitude/longitude la GENERATED ALWAYS tu location nen
/// bi OMIT khoi entity (xem CatalogDbContext).
/// </summary>
public sealed class Address : Entity
{
    private Address() { } // EF

    private Address(
        Guid id,
        string fullAddress,
        Point location,
        Guid? ownerUserId,
        string? label,
        string? ward,
        string? district,
        string? city,
        string country,
        string? placeId,
        string? provider,
        DateTimeOffset? verifiedAt,
        string? note) : base(id)
    {
        FullAddress = fullAddress;
        Location = location;
        OwnerUserId = ownerUserId;
        Label = label;
        Ward = ward;
        District = district;
        City = city;
        Country = country;
        PlaceId = placeId;
        Provider = provider;
        VerifiedAt = verifiedAt;
        Note = note;
    }

    public Guid? OwnerUserId { get; private set; }
    public string? Label { get; private set; }
    public string FullAddress { get; private set; } = null!;
    public string? Ward { get; private set; }
    public string? District { get; private set; }
    public string? City { get; private set; }
    public string Country { get; private set; } = null!;
    public string? PlaceId { get; private set; }
    public string? Provider { get; private set; }
    public DateTimeOffset? VerifiedAt { get; private set; }
    public bool IsVerified => !string.IsNullOrWhiteSpace(PlaceId) && VerifiedAt is not null;

    /// <summary>geography(Point,4326) — NOT NULL.</summary>
    public Point Location { get; private set; } = null!;
    public string? Note { get; private set; }

    public static Result<Address> Create(
        string fullAddress,
        Point location,
        Guid? ownerUserId = null,
        string? label = null,
        string? ward = null,
        string? district = null,
        string? city = null,
        string country = "Vietnam",
        string? placeId = null,
        string? provider = null,
        DateTimeOffset? verifiedAt = null,
        string? note = null)
    {
        if (string.IsNullOrWhiteSpace(fullAddress))
            return Error.Validation("address.full_address", "full_address la bat buoc.");
        if (location is null)
            return Error.Validation("address.location", "location la bat buoc.");
        if (string.IsNullOrWhiteSpace(country))
            return Error.Validation("address.country", "country la bat buoc.");

        return new Address(Guid.NewGuid(), fullAddress, location, ownerUserId,
            label, ward, district, city, country, placeId?.Trim(), provider?.Trim(),
            verifiedAt, note);
    }

    public Result Update(string fullAddress, Point location, string? label, string? ward,
        string? district, string? city, string country, string? placeId,
        string? provider, DateTimeOffset? verifiedAt, string? note)
    {
        if (string.IsNullOrWhiteSpace(fullAddress) || location is null || string.IsNullOrWhiteSpace(country))
            return Error.Validation("address.invalid", "Thong tin dia chi khong hop le.");

        FullAddress = fullAddress.Trim();
        Location = location;
        Label = label?.Trim();
        Ward = ward?.Trim();
        District = district?.Trim();
        City = city?.Trim();
        Country = country.Trim();
        PlaceId = placeId?.Trim();
        Provider = provider?.Trim();
        VerifiedAt = verifiedAt;
        Note = note?.Trim();
        return Result.Success();
    }
}
