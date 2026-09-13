using CareSitter.Modules.Identity.Domain;

namespace CareSitter.IntegrationTests;

public sealed class RefreshTokenSessionContractTests
{
    [Fact]
    public void Session_is_active_only_before_expiry_when_not_revoked()
    {
        var now = DateTimeOffset.UtcNow;
        var session = RefreshTokenSession.Create(
            Guid.NewGuid(),
            new string('a', 64),
            now,
            now.AddMinutes(10));

        Assert.True(session.IsActiveAt(now.AddMinutes(9)));
        Assert.False(session.IsActiveAt(now.AddMinutes(10)));
    }

    [Fact]
    public void Session_normalizes_optional_audit_metadata()
    {
        var now = DateTimeOffset.UtcNow;
        var session = RefreshTokenSession.Create(
            Guid.NewGuid(),
            new string('b', 64),
            now,
            now.AddDays(7),
            deviceId: "  device-01  ",
            deviceInfo: new string('x', 600),
            ipAddress: "  2001:db8::1  ");

        Assert.Equal("device-01", session.DeviceId);
        Assert.Equal(500, session.DeviceInfo!.Length);
        Assert.Equal("2001:db8::1", session.IpAddress);
    }

    [Fact]
    public void Reuse_security_audit_keeps_user_and_session_context()
    {
        var userId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();

        var result = AuditLog.Create(
            "REFRESH_TOKEN_REUSE_DETECTED",
            "REFRESH_TOKEN_SESSION",
            actorUserId: userId,
            entityId: sessionId,
            afterData: "{\"reason\":\"revoked_token_reused\"}",
            ipAddress: "127.0.0.1",
            userAgent: "test-agent");

        Assert.True(result.IsSuccess);
        Assert.Equal(userId, result.Value.ActorUserId);
        Assert.Equal(sessionId, result.Value.EntityId);
        Assert.Equal("127.0.0.1", result.Value.IpAddress);
        Assert.Contains("revoked_token_reused", result.Value.AfterData);
    }
}
