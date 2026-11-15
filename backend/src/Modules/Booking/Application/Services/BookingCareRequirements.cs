using CareSitter.Contracts.Services;
using CareSitter.SharedKernel.Results;
using CareSitter.SharedKernel.ValueObjects;

namespace CareSitter.Modules.Booking.Application;

internal static class BookingCareRequirements
{
    internal static async Task<Result<string[]>> ResolveAsync(Guid customerId, Guid? beneficiaryId,
        Guid serviceId, IReadOnlyList<string>? requested, IPeopleLookupService people,
        ICatalogLookupService catalog, CancellationToken ct)
    {
        var input = CareSkillSet.Normalize(requested, maximumCount: 60);
        if (input.IsFailure) return input.Error;
        var service = await catalog.GetRequiredCaregiverSkillsAsync(serviceId, ct);
        var recipient = beneficiaryId is { } id
            ? await people.GetRequiredCaregiverSkillsAsync(id, customerId, ct) : [];
        // Không suy diễn từ ghi chú/bệnh lý. Server luôn bổ sung nhu cầu đã được khai báo có cấu trúc.
        return CareSkillSet.Normalize(input.Value.Concat(service).Concat(recipient)
            .Distinct(StringComparer.Ordinal), maximumCount: 60);
    }
}
