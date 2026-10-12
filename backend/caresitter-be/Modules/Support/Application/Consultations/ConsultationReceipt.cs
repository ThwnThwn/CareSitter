namespace CareSitter.Modules.Support.Application.Consultations;

public sealed record ConsultationReceipt(Guid Id, DateTime CreatedAt);

public sealed record ConsultationResponse(Guid Id, string ContactName, string Phone,
    string ServiceCategory, DateOnly PreferredDate, int Hours, string? CaregiverPreference,
    string? Note, DateTime ConsentAt, DateTime CreatedAt);
