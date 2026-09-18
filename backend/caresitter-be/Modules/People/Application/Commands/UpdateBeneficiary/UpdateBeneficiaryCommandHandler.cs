using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Security;
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

    private static Result ApplyRequest(Beneficiary entity, UpdateBeneficiaryCommand request) =>
        entity.Update(request.FullName, request.DateOfBirth, NormalizeGender(request.Gender),
            request.RelationshipToCustomer, request.Phone, request.DefaultAddressId,
            request.MobilityNote, request.GeneralNote, request.HealthHistory?.GetRawText(),
            request.Allergies?.GetRawText(), request.ChronicConditions?.GetRawText(),
            request.CareInstructions, request.CareLevel, request.AvatarUrl,
            request.EmergencyContacts?.GetRawText(), request.Medications?.GetRawText());

    private static string? NormalizeGender(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return null;
        var gender = value.Trim().ToUpperInvariant();
        return gender is "MALE" or "FEMALE" or "OTHER" or "UNSPECIFIED" ? gender : string.Empty;
    }
}
