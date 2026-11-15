using System.Text;
using CareSitter.SharedKernel.Results;

namespace CareSitter.SharedKernel.ValueObjects;

public static class CareSkillSet
{
    public static Result<string[]> Normalize(IEnumerable<string>? values, int maximumCount = 20)
    {
        var source = values?.ToArray() ?? [];
        if (source.Length > maximumCount || source.Any(x => string.IsNullOrWhiteSpace(x) || x.Length > 100))
            return Error.Validation("care_needs.invalid", "Nhu cầu chăm sóc không hợp lệ: tối đa 20 kỹ năng, mỗi kỹ năng tối đa 100 ký tự.");
        return source.Select(x => string.Join(' ', x.Normalize(NormalizationForm.FormC).Trim()
            .ToLowerInvariant().Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)))
            .Distinct(StringComparer.Ordinal).OrderBy(x => x, StringComparer.Ordinal).ToArray();
    }
}
