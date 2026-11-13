using System.Text.Json;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class BeneficiaryDeletionParserTests
{
    [Fact]
    public void Valid_event_contains_only_ids_and_is_accepted()
    {
        var owner = Guid.NewGuid(); var beneficiary = Guid.NewGuid(); var eventId = Guid.NewGuid();
        var now = DateTimeOffset.UtcNow;
        var wire = JsonSerializer.Serialize(new
        {
            eventId, eventType = BeneficiaryDeletionProcessor.EventType, schemaVersion = 1,
            occurredAt = now, producer = "test", key = beneficiary.ToString("D"),
            payload = new { ownerUserId = owner, beneficiaryId = beneficiary, occurredAt = now }
        });
        var value = BeneficiaryDeletionProcessor.Parse(wire, beneficiary.ToString("D"), out var parsedId);
        Assert.Equal(eventId, parsedId);
        Assert.Equal(owner, value!.OwnerUserId);
        Assert.Equal(beneficiary, value.BeneficiaryId);
        Assert.Throws<InvalidDataException>(() => BeneficiaryDeletionProcessor.Parse(wire, Guid.NewGuid().ToString("D"), out _));
    }
}
