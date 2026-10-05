using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverKycApprovalResponse(Guid Id, string KycStatus);
