using System.Diagnostics;
using CareSitter.Messaging.Abstractions;
using CareSitter.Messaging.Contracts;
using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Persistence.Outbox;
using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.Infrastructure;

internal sealed class BeneficiaryDeletionEventWriter(
    MessagingSettings messaging,
    IEventSerializer serializer,
    OutboxWriter<PeopleDbContext>? outbox = null) : IBeneficiaryDeletionEventWriter
{
    public void Stage(Guid ownerUserId, Guid beneficiaryId, DateTimeOffset occurredAt)
    {
        if (messaging is not { Enabled: true, NutritionEnabled: true }) return;
        if (outbox is null) throw new InvalidOperationException("People Kafka outbox is unavailable.");
        var value = new BeneficiaryDeleted(ownerUserId, beneficiaryId, occurredAt);
        outbox.Add(serializer.Create(value, new EventMetadata(Guid.NewGuid(), occurredAt,
            messaging.Producer, beneficiaryId.ToString("D"), Activity.Current?.TraceId.ToString())));
    }
}
