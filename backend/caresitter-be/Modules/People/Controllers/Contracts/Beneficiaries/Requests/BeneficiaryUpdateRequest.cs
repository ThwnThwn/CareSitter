using System.Text.Json;
using System.Text.Json.Serialization;

namespace CareSitter.Modules.People.Controllers;

/// <summary>Giữ dấu trường có trong JSON để phân biệt bỏ qua với chủ động xóa bằng null.</summary>
public sealed class BeneficiaryUpdateRequest
{
    private readonly HashSet<string> _providedFields = new(StringComparer.Ordinal);

    [JsonIgnore]
    public IReadOnlySet<string> ProvidedFields => _providedFields;

    public string FullName { get; init; } = null!;
    public Guid? DefaultAddressId { get; init; }

    private DateOnly? _dateOfBirth;
    public DateOnly? DateOfBirth
    {
        get => _dateOfBirth;
        init { _dateOfBirth = value; _providedFields.Add(nameof(DateOfBirth)); }
    }

    private string? _gender;
    public string? Gender
    {
        get => _gender;
        init { _gender = value; _providedFields.Add(nameof(Gender)); }
    }

    private string? _relationshipToCustomer;
    public string? RelationshipToCustomer
    {
        get => _relationshipToCustomer;
        init { _relationshipToCustomer = value; _providedFields.Add(nameof(RelationshipToCustomer)); }
    }

    private string? _phone;
    public string? Phone
    {
        get => _phone;
        init { _phone = value; _providedFields.Add(nameof(Phone)); }
    }

    private string? _mobilityNote;
    public string? MobilityNote
    {
        get => _mobilityNote;
        init { _mobilityNote = value; _providedFields.Add(nameof(MobilityNote)); }
    }

    private string? _generalNote;
    public string? GeneralNote
    {
        get => _generalNote;
        init { _generalNote = value; _providedFields.Add(nameof(GeneralNote)); }
    }

    private JsonElement? _healthHistory;
    public JsonElement? HealthHistory
    {
        get => _healthHistory;
        init { _healthHistory = value; _providedFields.Add(nameof(HealthHistory)); }
    }

    private JsonElement? _allergies;
    public JsonElement? Allergies
    {
        get => _allergies;
        init { _allergies = value; _providedFields.Add(nameof(Allergies)); }
    }

    private JsonElement? _chronicConditions;
    public JsonElement? ChronicConditions
    {
        get => _chronicConditions;
        init { _chronicConditions = value; _providedFields.Add(nameof(ChronicConditions)); }
    }

    private string? _careInstructions;
    public string? CareInstructions
    {
        get => _careInstructions;
        init { _careInstructions = value; _providedFields.Add(nameof(CareInstructions)); }
    }

    private string? _careLevel;
    public string? CareLevel
    {
        get => _careLevel;
        init { _careLevel = value; _providedFields.Add(nameof(CareLevel)); }
    }

    private string? _avatarUrl;
    public string? AvatarUrl
    {
        get => _avatarUrl;
        init { _avatarUrl = value; _providedFields.Add(nameof(AvatarUrl)); }
    }

    private JsonElement? _emergencyContacts;
    public JsonElement? EmergencyContacts
    {
        get => _emergencyContacts;
        init { _emergencyContacts = value; _providedFields.Add(nameof(EmergencyContacts)); }
    }

    private JsonElement? _medications;
    public JsonElement? Medications
    {
        get => _medications;
        init { _medications = value; _providedFields.Add(nameof(Medications)); }
    }
}
