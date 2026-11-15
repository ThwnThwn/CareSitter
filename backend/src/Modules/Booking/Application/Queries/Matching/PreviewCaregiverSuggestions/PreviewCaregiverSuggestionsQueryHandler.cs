using System.Text.Json;
using CareSitter.Contracts.Services;
using CareSitter.Modules.Booking.Application.Commands;
using CareSitter.SharedKernel.Results;
using MediatR;

namespace CareSitter.Modules.Booking.Application;

internal sealed class PreviewCaregiverSuggestionsQueryHandler(
    ICurrentUser user, IClock clock, IPeopleLookupService people,
    ICatalogLookupService catalog, IBookingMatchingPreview matching,
    IBookingResponseMapper mapper)
    : IRequestHandler<PreviewCaregiverSuggestionsQuery, Result<CaregiverSuggestionListResponse>>
{
    public async Task<Result<CaregiverSuggestionListResponse>> Handle(
        PreviewCaregiverSuggestionsQuery request, CancellationToken ct)
    {
        if (user.UserId is not { } customerId) return BookingErrors.Unauthenticated();
        if (request.ScheduledStart <= clock.UtcNow || request.ScheduledEnd <= request.ScheduledStart ||
            request.ScheduledEnd - request.ScheduledStart > TimeSpan.FromHours(24) ||
            request.RequiredSkills is { Count: > 60 } ||
            request.RequiredSkills?.Any(x => string.IsNullOrWhiteSpace(x) || x.Length > 100) == true)
            return Error.Validation("booking.suggestions.request", "Khung giờ hoặc nhu cầu chăm sóc không hợp lệ.");
        if ((request.BeneficiaryId is { } beneficiaryId &&
                !await people.BeneficiaryBelongsToAsync(beneficiaryId, customerId, ct)) ||
            !await catalog.AddressBelongsToAsync(request.AddressId, customerId, ct))
            return BookingErrors.Forbidden();
        if (!await catalog.AddressIsVerifiedForBookingAsync(request.AddressId, customerId, ct))
            return Error.Validation("booking.address_unverified", "Vui lòng chọn địa chỉ đã xác minh.");
        if (!await catalog.ServiceIsActiveAsync(request.ServiceTypeId, ct))
            return Error.Validation("booking.service", "Dịch vụ không hoạt động.");
        var needs = await BookingCareRequirements.ResolveAsync(customerId, request.BeneficiaryId,
            request.ServiceTypeId, request.RequiredSkills, people, catalog, ct);
        if (needs.IsFailure) return needs.Error;
        // Preview không ghi DB; hồ sơ bản thân có thể chỉ được tạo ở bước xác nhận cuối.
        var draft = Domain.Booking.Create(customerId, request.BeneficiaryId ?? Guid.Empty, request.AddressId,
            request.ServiceTypeId, request.ScheduledStart, request.ScheduledEnd,
            requiredSkills: needs.Value.Length > 0
                ? JsonSerializer.Serialize(needs.Value) : null);
        if (draft.IsFailure) return draft.Error;
        var candidates = await matching.PreviewAsync(draft.Value, ct);
        var items = new List<CaregiverSuggestionResponse>();
        foreach (var candidate in candidates.Take(Math.Clamp(request.Limit, 1, 20)))
            items.Add(mapper.ToCaregiverSuggestion(candidate,
                await people.GetCaregiverDisplayAsync(candidate.CaregiverId, ct)));
        return new CaregiverSuggestionListResponse(items, candidates.Count);
    }
}
