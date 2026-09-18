using CareSitter.Modules.People.Application.Commands.CreateBeneficiary;
using CareSitter.Modules.People.Application.Commands.SubmitCaregiverKyc;
using CareSitter.Modules.Support.Application.Commands.CreateReview;
using CareSitter.Modules.Support.Application.Commands.CreateSupportTicket;

namespace CareSitter.IntegrationTests;

public sealed class ModuleCommandValidatorTests
{
    [Fact]
    public void Beneficiary_validation_keeps_gender_before_date_and_address()
    {
        var validator = new CreateBeneficiaryCommandValidator();
        var command = new CreateBeneficiaryCommand("Name", DateOnly.MaxValue,
            "invalid", null, null, null, null, null, null, null, null, null, null, null,
            null, null);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Equal("Giới tính không hợp lệ.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Beneficiary_validation_rejects_fake_care_level_and_local_avatar_path()
    {
        var validator = new CreateBeneficiaryCommandValidator();
        var command = new CreateBeneficiaryCommand("Name", null,
            null, null, null, Guid.NewGuid(), null, null, null, null, null, null,
            "Rất nặng", "C:\\temp\\avatar.jpg", null, null);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors,
            error => error.ErrorCode == "beneficiary.care_level");
        Assert.Contains(result.Errors,
            error => error.ErrorCode == "beneficiary.avatar_url");
    }

    [Fact]
    public void Kyc_validation_keeps_cccd_as_first_check()
    {
        var validator = new SubmitCaregiverKycCommandValidator();

        var result = validator.Validate(new SubmitCaregiverKycCommand(
            "abc", "invalid", "invalid", null));

        Assert.False(result.IsValid);
        Assert.Single(result.Errors);
        Assert.Equal("So CCCD phai gom 9 hoac 12 chu so.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Review_validation_keeps_required_ids_as_first_check()
    {
        var validator = new CreateReviewCommandValidator();

        var result = validator.Validate(new CreateReviewCommand(
            Guid.Empty, Guid.Empty, 5, new string('x', 1_001), null));

        Assert.False(result.IsValid);
        Assert.Single(result.Errors);
        Assert.Equal("Booking và caregiver là bắt buộc.", result.Errors[0].ErrorMessage);
    }

    [Fact]
    public void Ticket_validation_keeps_legacy_attachment_message()
    {
        var validator = new CreateSupportTicketCommandValidator();

        var result = validator.Validate(new CreateSupportTicketCommand(
            "GENERAL", "Title", "Long description", null, null, ["ftp://invalid"]));

        Assert.False(result.IsValid);
        Assert.Equal("Danh sach tep dinh kem khong hop le hoac vuot qua 5 tep.",
            result.Errors[0].ErrorMessage);
    }
}
