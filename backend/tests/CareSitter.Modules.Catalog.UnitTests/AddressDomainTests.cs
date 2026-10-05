using CareSitter.Modules.Catalog.Domain;
using NetTopologySuite.Geometries;

namespace CareSitter.Modules.Catalog.UnitTests;

public sealed class AddressDomainTests
{
    private static Point Location() => new(106.7, 10.8) { SRID = 4326 };

    [Fact]
    public void Verified_address_requires_both_place_id_and_timestamp()
    {
        var owner = Guid.NewGuid();
        var address = Address.Create("123 Test", Location(), ownerUserId: owner,
            placeId: " place-1 ", provider: " geo ", verifiedAt: DateTimeOffset.UtcNow).Value;
        Assert.True(address.IsVerified);
        Assert.Equal("place-1", address.PlaceId);
        Assert.Equal("geo", address.Provider);
        Assert.Equal(owner, address.OwnerUserId);
        Assert.False(Address.Create("123 Test", Location(), placeId: "place-1").Value.IsVerified);
        Assert.False(Address.Create("123 Test", Location(), verifiedAt: DateTimeOffset.UtcNow).Value.IsVerified);
    }

    [Theory]
    [InlineData("", "Vietnam", "address.full_address")]
    [InlineData("123 Test", "", "address.country")]
    public void Required_address_fields_are_validated(string fullAddress, string country, string error)
        => Assert.Equal(error, Address.Create(fullAddress, Location(), country: country).Error.Code);

    [Fact]
    public void Missing_location_is_rejected()
        => Assert.Equal("address.location", Address.Create("123 Test", null!).Error.Code);

    [Fact]
    public void Invalid_update_keeps_existing_address()
    {
        var address = Address.Create("123 Test", Location()).Value;
        Assert.True(address.Update("", Location(), null, null, null, null,
            "Vietnam", null, null, null, null).IsFailure);
        Assert.Equal("123 Test", address.FullAddress);
    }
}
