using System.Text.Json;

namespace CareSitter.Modules.People.Application;

public sealed record CaregiverKycRejectionResponse(Guid Id, string KycStatus, string? Reason);
