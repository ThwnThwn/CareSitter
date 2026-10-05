using CareSitter.Modules.People.Domain;

namespace CareSitter.Modules.People.UnitTests;

public sealed class CaregiverDomainTests
{
    [Fact]
    public void Empty_user_is_rejected_and_new_profile_is_offline_draft()
    {
        Assert.True(CaregiverProfile.Create(Guid.Empty).IsFailure);
        var user = Guid.NewGuid();
        var profile = CaregiverProfile.Create(user).Value;
        Assert.Equal(user, profile.UserId);
        Assert.Equal("OFFLINE", profile.AvailabilityStatus);
        Assert.Equal("DRAFT", profile.KycStatus);
    }

    [Theory]
    [InlineData("online", "ONLINE")]
    [InlineData(" Busy ", "BUSY")]
    [InlineData("OFFLINE", "OFFLINE")]
    public void Availability_is_normalized(string input, string expected)
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        Assert.True(profile.SetAvailabilityStatus(input).IsSuccess);
        Assert.Equal(expected, profile.AvailabilityStatus);
    }

    [Fact]
    public void Invalid_availability_does_not_mutate_profile()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        Assert.True(profile.SetAvailabilityStatus("INVALID").IsFailure);
        Assert.Equal("OFFLINE", profile.AvailabilityStatus);
    }

    [Fact]
    public void Secure_kyc_rejects_same_image_and_allows_rejected_resubmission()
    {
        var profile = CaregiverProfile.Create(Guid.NewGuid()).Value;
        var front = Guid.NewGuid();
        Assert.True(profile.ApproveKyc().IsFailure);
        Assert.True(profile.SubmitSecureKyc("cipher", "hash", front, front, "[]").IsFailure);
        Assert.Equal("DRAFT", profile.KycStatus);
        Assert.True(profile.SubmitSecureKyc("cipher", "hash", front, Guid.NewGuid(), "[]").IsSuccess);
        Assert.Null(profile.CccdFrontUrl);
        Assert.True(profile.RejectKyc().IsSuccess);
        Assert.True(profile.SubmitSecureKyc("cipher", "hash", Guid.NewGuid(), Guid.NewGuid(), "[]").IsSuccess);
        Assert.True(profile.ApproveKyc().IsSuccess);
        Assert.True(profile.RejectKyc().IsFailure);
        Assert.Equal("APPROVED", profile.KycStatus);
    }
}
