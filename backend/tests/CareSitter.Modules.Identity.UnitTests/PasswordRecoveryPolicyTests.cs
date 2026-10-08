using CareSitter.Modules.Identity.Domain;
using CareSitter.Modules.Identity.Domain.Policies;

namespace CareSitter.Modules.Identity.UnitTests;

public sealed class PasswordRecoveryPolicyTests
{
    [Theory]
    [InlineData("short1A", false)]
    [InlineData("lowercase123", false)]
    [InlineData("NoDigitsHere", false)]
    [InlineData("ValidPass123", true)]
    public void Password_policy_is_shared_and_enforces_complexity(string password, bool valid)
        => Assert.Equal(valid, PasswordPolicy.Validate(password).IsSuccess);

    [Fact]
    public void Password_limit_counts_utf8_bytes_not_characters()
    {
        Assert.True(PasswordPolicy.Validate("A1" + new string('a', 70)).IsSuccess);
        Assert.False(PasswordPolicy.Validate("A1" + new string('a', 71)).IsSuccess);
        Assert.False(PasswordPolicy.Validate("A1" + new string('ệ', 24)).IsSuccess);
    }

    [Fact]
    public void Changing_email_clears_ownership_evidence_and_changes_version()
    {
        var user = User.Create(Guid.NewGuid(), "old@example.com").Value;
        user.VerifyEmail(DateTimeOffset.UtcNow);
        var version = user.RecoveryVersion;
        user.UpdateProfile("Name", "new@example.com", "Name");
        Assert.Null(user.EmailVerifiedAt);
        Assert.True(user.RecoveryVersion > version);
        user.VerifyEmail(DateTimeOffset.UtcNow);
        version = user.RecoveryVersion;
        user.UpdateProfile("Other name", "NEW@example.com", "Other name");
        Assert.NotNull(user.EmailVerifiedAt);
        Assert.Equal(version, user.RecoveryVersion);
    }

    [Fact]
    public void Security_changes_invalidate_previous_recovery_version()
    {
        var user = User.Create(Guid.NewGuid(), "care@example.com").Value;
        var version = user.RecoveryVersion;
        user.SetPassword("hash"); Assert.True(user.RecoveryVersion > version);
        version = user.RecoveryVersion;
        user.SetStatus("LOCKED"); Assert.True(user.RecoveryVersion > version);
        version = user.RecoveryVersion;
        user.SetRoles(["ADMIN"]); Assert.True(user.RecoveryVersion > version);
    }
}
