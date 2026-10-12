using CareSitter.Contracts.Services;
using CareSitter.Modules.People.Application.Commands.CreateBeneficiary;
using CareSitter.Modules.People.Domain;
using CareSitter.SharedKernel.Results;
using FluentValidation;
using MediatR;

namespace CareSitter.Modules.People.Application.Commands.SelfBeneficiary;

internal sealed class CreateSelfBeneficiaryCommandHandler(IPeopleRepository repository,
    ICurrentUser currentUser, ICatalogLookupService catalog, IValidator<CreateBeneficiaryCommand> validator)
    : IRequestHandler<CreateSelfBeneficiaryCommand, Result<SelfBeneficiaryCreationResponse>>
{
    public async Task<Result<SelfBeneficiaryCreationResponse>> Handle(CreateSelfBeneficiaryCommand request, CancellationToken ct)
    {
        if (SelfBeneficiaryRules.Authorize(currentUser) is { } error) return error;
        var userId = currentUser.UserId!.Value;
        await using var tx = await repository.BeginUserScopeAsync(userId, ct);
        await repository.LockSelfBeneficiaryAsync(userId, ct);
        var existing = await repository.GetSelfBeneficiaryAsync(userId, ct);
        // Retry phải trả dữ liệu đã lưu trước khi validate draft cũ, tuyệt đối không ghi đè.
        if (existing is not null)
        {
            if (existing.DeletedAt is not null) return SelfBeneficiaryRules.Archived();
            return new SelfBeneficiaryCreationResponse(PeopleResponseMapper.ToResponse(existing), false);
        }
        var validation = await validator.ValidateAsync(new CreateBeneficiaryCommand(request.FullName,
            request.DateOfBirth, request.Gender, "Bản thân", request.Phone, request.DefaultAddressId,
            null, request.GeneralNote, null, null, null, request.CareInstructions, request.CareLevel,
            request.AvatarUrl, request.EmergencyContacts, null), ct);
        if (!validation.IsValid) return Error.Validation(validation.Errors[0].ErrorCode, validation.Errors[0].ErrorMessage);
        if (request.Phone?.Length > 20)
            return Error.Validation("beneficiary.phone", "Số điện thoại không hợp lệ.");
        if (!SelfBeneficiaryRules.HasValidContacts(request.EmergencyContacts))
            return Error.Validation("beneficiary.emergency_contacts", "Cần ít nhất hai liên hệ khẩn cấp hợp lệ, khác số điện thoại.");
        var addressId = request.DefaultAddressId!.Value;
        if (!await catalog.AddressBelongsToAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address", "Địa chỉ không tồn tại hoặc không thuộc người dùng.");
        if (!await catalog.AddressIsVerifiedForBookingAsync(addressId, userId, ct))
            return Error.Validation("beneficiary.address_unverified", "Vui lòng chọn địa chỉ đã xác minh.");
        var created = Beneficiary.Create(userId, request.FullName);
        if (created.IsFailure) return created.Error;
        var entity = created.Value;
        var updated = entity.Update(request.FullName, request.DateOfBirth,
            string.IsNullOrWhiteSpace(request.Gender) ? null : request.Gender.Trim().ToUpperInvariant(),
            "Bản thân", request.Phone, addressId, null, request.GeneralNote, null, null, null,
            request.CareInstructions, request.CareLevel, request.AvatarUrl,
            request.EmergencyContacts?.GetRawText(), null);
        if (updated.IsFailure) return updated.Error;
        var marked = entity.MarkAsSelf();
        if (marked.IsFailure) return marked.Error;
        repository.AddBeneficiary(entity);
        await repository.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new SelfBeneficiaryCreationResponse(PeopleResponseMapper.ToResponse(entity), true);
    }
}
