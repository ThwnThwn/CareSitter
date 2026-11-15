namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

public sealed record SelfBeneficiaryCreationResponse(BeneficiaryResponse Beneficiary, bool Created);
