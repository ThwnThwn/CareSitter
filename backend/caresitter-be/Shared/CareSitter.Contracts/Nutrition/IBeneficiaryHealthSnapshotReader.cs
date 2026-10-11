namespace CareSitter.Contracts.Nutrition;

public interface IBeneficiaryHealthSnapshotReader
{
    Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid ownerId,Guid beneficiaryId,CancellationToken ct=default);
}
