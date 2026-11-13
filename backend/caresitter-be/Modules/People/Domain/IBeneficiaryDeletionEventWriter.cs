namespace CareSitter.Modules.People.Domain;

/// <summary>Stages a durable integration event in the current People transaction.</summary>
public interface IBeneficiaryDeletionEventWriter
{
    void Stage(Guid ownerUserId, Guid beneficiaryId, DateTimeOffset occurredAt);
}
