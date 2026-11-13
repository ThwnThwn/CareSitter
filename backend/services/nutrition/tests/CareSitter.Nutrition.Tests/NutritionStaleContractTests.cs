using CareSitter.Nutrition.Grpc.V1;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;

namespace CareSitter.Nutrition.Tests;

public sealed class NutritionStaleContractTests
{
    [Fact]
    public void Committed_stale_resource_round_trips_protobuf_without_changing_revision()
    {
        var id = Guid.NewGuid().ToString();
        var response = new ResourceResult { Resource = new Resource
        {
            Id = id, BeneficiaryId = Guid.NewGuid().ToString(), HealthRevision = 7,
            Status = "stale", DataJson = "{}", CreatedAt = Timestamp.FromDateTime(DateTime.UtcNow)
        } };
        var decoded = ResourceResult.Parser.ParseFrom(response.ToByteArray());
        Assert.Equal(ResourceResult.OutcomeOneofCase.Resource, decoded.OutcomeCase);
        Assert.Equal("stale", decoded.Resource.Status);
        Assert.Equal(id, decoded.Resource.Id);
        Assert.Equal(7, decoded.Resource.HealthRevision);
    }
}
