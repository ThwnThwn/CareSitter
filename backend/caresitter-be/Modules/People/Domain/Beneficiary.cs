using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Domain;

/// <summary>
/// Aggregate root cho nguoi duoc cham soc (beneficiary). Map sang bang people.beneficiaries.
/// Du lieu y te nhay cam (health_history, allergies, chronic_conditions, medications) duoc
/// bao ve bang Row-Level Security theo customer_id. Cac cot jsonb giu nguyen dang string?.
/// </summary>
public sealed class Beneficiary : AggregateRoot
{
    private Beneficiary() { } // EF

    private Beneficiary(Guid id, Guid customerId, string fullName) : base(id)
    {
        CustomerId = customerId;
        FullName = fullName;
    }

    public Guid CustomerId { get; private set; }
    public string FullName { get; private set; } = null!;
    public DateOnly? DateOfBirth { get; private set; }

    /// <summary>Allowed values: MALE, FEMALE, OTHER, UNSPECIFIED.</summary>
    public string? Gender { get; private set; }
    public string? RelationshipToCustomer { get; private set; }
    public string? Phone { get; private set; }
    public Guid? DefaultAddressId { get; private set; }
    public string? MobilityNote { get; private set; }
    public string? GeneralNote { get; private set; }

    /// <summary>jsonb: gom beneficiary_health_profiles.</summary>
    public string? HealthHistory { get; private set; }

    /// <summary>jsonb.</summary>
    public string? Allergies { get; private set; }

    /// <summary>jsonb.</summary>
    public string? ChronicConditions { get; private set; }
    public string? CareInstructions { get; private set; }

    /// <summary>jsonb: gom emergency_contacts.</summary>
    public string? EmergencyContacts { get; private set; }

    /// <summary>jsonb: [{name,dosage,schedule,instruction,start_date,end_date,is_active}].</summary>
    public string? Medications { get; private set; }

    public DateTimeOffset? DeletedAt { get; private set; }

    public static Result<Beneficiary> Create(Guid customerId, string fullName)
    {
        if (customerId == Guid.Empty)
            return Error.Validation("beneficiary.customer", "customer_id la bat buoc.");
        if (string.IsNullOrWhiteSpace(fullName))
            return Error.Validation("beneficiary.full_name", "full_name la bat buoc.");

        return new Beneficiary(Guid.NewGuid(), customerId, fullName);
    }
}
