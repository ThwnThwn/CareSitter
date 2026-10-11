namespace CareSitter.Nutrition.Contracts;

public interface IPeopleHealthClient
{
    Task<BeneficiaryHealthSnapshot?> ReadAsync(Guid owner, Guid beneficiary, CancellationToken ct);
}
