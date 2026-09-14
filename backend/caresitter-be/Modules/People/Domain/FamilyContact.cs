using CareSitter.SharedKernel.Domain;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Domain;

/// <summary>Một liên hệ dùng chung của gia đình, có thể chọn lại cho nhiều người được chăm sóc.</summary>
public sealed class FamilyContact : Entity
{
    private FamilyContact() { }

    private FamilyContact(Guid id, Guid customerId, string fullName, string phoneNumber) : base(id)
    {
        CustomerId = customerId;
        FullName = fullName;
        PhoneNumber = phoneNumber;
    }

    public Guid CustomerId { get; private set; }
    public string FullName { get; private set; } = null!;
    public string PhoneNumber { get; private set; } = null!;
    public string? Note { get; private set; }
    public DateTimeOffset? DeletedAt { get; private set; }

    public static Result<FamilyContact> Create(Guid customerId, string fullName, string phoneNumber, string? note)
    {
        if (customerId == Guid.Empty)
            return Error.Validation("family_contact.customer", "Tài khoản không hợp lệ.");
        if (!IsValidName(fullName))
            return Error.Validation("family_contact.full_name", "Họ tên liên hệ không hợp lệ.");
        if (!IsValidPhone(phoneNumber))
            return Error.Validation("family_contact.phone", "Số điện thoại liên hệ không hợp lệ.");

        var contact = new FamilyContact(Guid.NewGuid(), customerId, fullName.Trim(), NormalizePhone(phoneNumber));
        contact.Note = NormalizeNote(note);
        return contact;
    }

    public Result Update(string fullName, string phoneNumber, string? note)
    {
        if (!IsValidName(fullName))
            return Error.Validation("family_contact.full_name", "Họ tên liên hệ không hợp lệ.");
        if (!IsValidPhone(phoneNumber))
            return Error.Validation("family_contact.phone", "Số điện thoại liên hệ không hợp lệ.");

        FullName = fullName.Trim();
        PhoneNumber = NormalizePhone(phoneNumber);
        Note = NormalizeNote(note);
        return Result.Success();
    }

    public void Delete(DateTimeOffset deletedAt) => DeletedAt = deletedAt;

    private static bool IsValidName(string value) => !string.IsNullOrWhiteSpace(value) && value.Trim().Length <= 255;
    private static bool IsValidPhone(string value)
    {
        var normalized = NormalizePhone(value);
        return normalized.Length is >= 8 and <= 20 && normalized.All(char.IsDigit);
    }

    private static string NormalizePhone(string value) => new(value.Where(char.IsDigit).ToArray());
    private static string? NormalizeNote(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
