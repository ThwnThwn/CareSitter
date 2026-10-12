using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.UpdateBeneficiary;

internal sealed class UpdateBeneficiaryCommandHandler(
    IPeopleRepository repository,
    ICurrentUser currentUser,
    ICatalogLookupService catalog,
    IValidator<UpdateBeneficiaryCommand> validator)
    : IRequestHandler<UpdateBeneficiaryCommand, Result<BeneficiaryResponse>>
{
    public async Task<Result<BeneficiaryResponse>> Handle(
        UpdateBeneficiaryCommand request, CancellationToken ct)
    {
        if (currentUser.UserId is not { } userId) return PeopleErrors.Unauthenticated();
        var validation = await validator.ValidateAsync(request, ct);
        if (!validation.IsValid)
            return Error.Validation(validation.Errors[0].ErrorCode,
                validation.Errors[0].ErrorMessage);
        var addressId = request.DefaultAddressId!.Value;
        if (!await catalog.AddressBelongsToAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address",
                "Địa chỉ không tồn tại hoặc không thuộc người dùng.");
        if (!await catalog.AddressIsVerifiedForBookingAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address_unverified",
                "Vui lòng chọn địa chỉ từ danh sách gợi ý trước khi lưu.");

        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        var entity = await repository.GetBeneficiaryAsync(request.BeneficiaryId, userId, ct);
        if (entity is null) return PeopleErrors.NotFound();
        var result = ApplyRequest(entity, request);
        if (result.IsFailure) return result.Error;
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return PeopleResponseMapper.ToResponse(entity);
    }

    private static Result ApplyRequest(Beneficiary entity, UpdateBeneficiaryCommand request)
    {
        // Merge với entity vừa đọc trong scope của owner, không lấy dữ liệu sức khỏe từ bản sao cũ của app.
        T Field<T>(string name, T incoming, T stored) =>
            request.ProvidedFields is null || request.ProvidedFields.Contains(name) ? incoming : stored;

        return entity.Update(request.FullName,
            Field(nameof(request.DateOfBirth), request.DateOfBirth, entity.DateOfBirth),
            Field(nameof(request.Gender), NormalizeGender(request.Gender), entity.Gender),
            Field(nameof(request.RelationshipToCustomer), request.RelationshipToCustomer, entity.RelationshipToCustomer),
            Field(nameof(request.Phone), request.Phone, entity.Phone), request.DefaultAddressId,
            Field(nameof(request.MobilityNote), request.MobilityNote, entity.MobilityNote),
            Field(nameof(request.GeneralNote), request.GeneralNote, entity.GeneralNote),
            Field(nameof(request.HealthHistory), JsonText(request.HealthHistory), entity.HealthHistory),
            Field(nameof(request.Allergies), JsonText(request.Allergies), entity.Allergies),
            Field(nameof(request.ChronicConditions), JsonText(request.ChronicConditions), entity.ChronicConditions),
            Field(nameof(request.CareInstructions), request.CareInstructions, entity.CareInstructions),
            Field(nameof(request.CareLevel), request.CareLevel, entity.CareLevel),
            Field(nameof(request.AvatarUrl), request.AvatarUrl, entity.AvatarUrl),
            Field(nameof(request.EmergencyContacts), JsonText(request.EmergencyContacts), entity.EmergencyContacts),
            Field(nameof(request.Medications), JsonText(request.Medications), entity.Medications));
    }

    private static string? JsonText(System.Text.Json.JsonElement? value) =>
        value is null || value.Value.ValueKind == System.Text.Json.JsonValueKind.Null
            ? null : value.Value.GetRawText();

    private static string? NormalizeGender(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var gender = value.Trim().ToUpperInvariant();
        return gender is "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED" ? gender : string.Empty;
    }
}
