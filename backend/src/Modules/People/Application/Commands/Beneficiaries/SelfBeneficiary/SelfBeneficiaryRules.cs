using System.Text.Json;
using System.Text.RegularExpressions;
using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

internal static class SelfBeneficiaryRules
{
    public static Error? Authorize(ICurrentUser user) => user.UserId is null
        ? PeopleErrors.Unauthenticated()
        : !user.IsInRole("CUSTOMER")
            ? Error.Forbidden("beneficiary.customer_required", "Chỉ khách hàng được quản lý hồ sơ bản thân.") : null;

    public static Error Archived() => Error.Conflict("beneficiary.self_archived",
        "Hồ sơ bản thân đã ngừng hoạt động. Vui lòng liên hệ hỗ trợ.");

    public static bool HasValidContacts(JsonElement? value)
    {
        if (value is not { ValueKind: JsonValueKind.Array } contacts || contacts.GetArrayLength() < 2)
            return false;
        var phones = new HashSet<string>();
        foreach (var contact in contacts.EnumerateArray())
        {
            if (contact.ValueKind != JsonValueKind.Object) return false;
            string? Read(string name) => contact.EnumerateObject()
                .Where(p => p.Name.Equals(name, StringComparison.OrdinalIgnoreCase))
                .Select(p => p.Value.ValueKind == JsonValueKind.String ? p.Value.GetString() : null).FirstOrDefault();
            if (string.IsNullOrWhiteSpace(Read("name"))) return false;
            var phone = Regex.Replace(Read("phone") ?? "", @"[\s().-]", "");
            if (phone.StartsWith("+84", StringComparison.Ordinal)) phone = "0" + phone[3..];
            if (!Regex.IsMatch(phone, @"^0[3-9][0-9]{8}$") || !phones.Add(phone)) return false;
        }
        return true;
    }
}
