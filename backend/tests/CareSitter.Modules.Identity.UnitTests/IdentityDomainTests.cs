using CareSitter.Modules.Identity.Domain;

namespace CareSitter.Modules.Identity.UnitTests;

public sealed class IdentityDomainTests
{
    [Fact]
    public void User_email_is_normalized()
    {
        var user = User.Create(Guid.NewGuid(), "  Care@Example.COM ").Value;
        Assert.Equal("care@example.com", user.Email);
        Assert.Equal("ACTIVE", user.Status);
    }

    [Theory]
    [InlineData("")]
    [InlineData(" ")]
    public void Empty_email_is_rejected(string email)
        => Assert.Equal("user.email", User.Create(Guid.NewGuid(), email).Error.Code);

    [Theory]
    [InlineData(" locked ", "LOCKED")]
    [InlineData("suspended", "SUSPENDED")]
    [InlineData("ACTIVE", "ACTIVE")]
    public void Supported_user_status_is_normalized(string input, string expected)
    {
        var user = User.Create(Guid.NewGuid(), "care@example.com").Value;
        Assert.True(user.SetStatus(input).IsSuccess);
        Assert.Equal(expected, user.Status);
    }

    [Fact]
    public void Invalid_status_does_not_mutate_user()
    {
        var user = User.Create(Guid.NewGuid(), "care@example.com").Value;
        Assert.Equal("user.status", user.SetStatus("DELETED").Error.Code);
        Assert.Equal("ACTIVE", user.Status);
    }

    [Fact]
    public void Refresh_session_expires_at_exact_deadline_and_normalizes_metadata()
    {
        var now = DateTimeOffset.Parse("2026-10-04T00:00:00Z");
        var session = RefreshTokenSession.Create(Guid.NewGuid(), new string('a', 64),
            now, now.AddMinutes(10), " device ", new string('x', 510), " ");
        Assert.True(session.IsActiveAt(now.AddMinutes(10).AddTicks(-1)));
        Assert.False(session.IsActiveAt(now.AddMinutes(10)));
        Assert.Equal("device", session.DeviceId);
        Assert.Equal(500, session.DeviceInfo!.Length);
        Assert.Null(session.IpAddress);
        Assert.Equal(now, session.CreatedAt);
    }
}
