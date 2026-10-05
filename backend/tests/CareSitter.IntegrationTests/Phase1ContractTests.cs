using CareSitter.Modules.People.Domain;
using CareSitter.Modules.Support.Domain;

namespace CareSitter.IntegrationTests;

public sealed class Phase1ContractTests
{
    [Fact]
    public void Legacy_resubmission_cannot_retain_secure_references_from_an_older_submission()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        Assert.True(profile.SubmitSecureKyc("encrypted", "hash", Guid.NewGuid(), Guid.NewGuid(), "[]").IsSuccess);
        Assert.True(profile.RejectKyc().IsSuccess);
        Assert.True(profile.SubmitKyc("encrypted", "hash", "https://legacy.invalid/front.png", "https://legacy.invalid/back.png").IsSuccess);
        Assert.Null(profile.CccdFrontMediaId);
        Assert.Null(profile.CccdBackMediaId);
        Assert.Equal("[]", profile.CertificateMediaIds);
    }

    [Fact]
    public void Kyc_requires_both_cccd_images_before_pending()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;

        var result = profile.SubmitKyc(
            "encrypted", "hash", string.Empty,
            "https://cdn.example/cccd-back.jpg", "[]");

        Assert.True(result.IsFailure);
        Assert.Equal("DRAFT", profile.KycStatus);
    }

    [Fact]
    public void Kyc_submission_keeps_document_urls_and_moves_to_pending()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;

        var result = profile.SubmitKyc(
            "encrypted",
            "hash",
            "https://cdn.example/cccd-front.jpg",
            "https://cdn.example/cccd-back.jpg",
            "[\"https://cdn.example/certificate.jpg\"]");

        Assert.True(result.IsSuccess);
        Assert.Equal("PENDING", profile.KycStatus);
        Assert.Equal("https://cdn.example/cccd-front.jpg", profile.CccdFrontUrl);
        Assert.Equal("https://cdn.example/cccd-back.jpg", profile.CccdBackUrl);
        Assert.Contains("certificate.jpg", profile.CertificateUrls);
    }

    [Fact]
    public void Support_ticket_requires_meaningful_title_and_description()
    {
        var result = SupportTicket.Create(
            Guid.NewGuid(), "GENERAL", title: "Hi", description: "Too short");

        Assert.True(result.IsFailure);
    }

    [Fact]
    public void Support_ticket_normalizes_contract_and_keeps_content()
    {
        var result = SupportTicket.Create(
            Guid.NewGuid(),
            "general",
            "medium",
            title: "  Không check-in được  ",
            description: "  Ứng dụng báo lỗi khi tôi bấm nút check-in.  ",
            attachmentUrls: "[\"https://cdn.example/error.jpg\"]");

        Assert.True(result.IsSuccess);
        Assert.Equal("GENERAL", result.Value.Type);
        Assert.Equal("MEDIUM", result.Value.Priority);
        Assert.Equal("Không check-in được", result.Value.Title);
        Assert.StartsWith("Ứng dụng", result.Value.Description);
        Assert.Contains("error.jpg", result.Value.AttachmentUrls);
    }
}
