using System.Net;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class IdentitySessionClientTests
{
    [Theory]
    [InlineData(HttpStatusCode.NoContent, true)]
    [InlineData(HttpStatusCode.Unauthorized, false)]
    [InlineData(HttpStatusCode.Forbidden, false)]
    public async Task Session_probe_uses_bearer_and_no_profile_payload(HttpStatusCode status, bool active)
    {
        using var client = new HttpClient(new Handler(request =>
        {
            Assert.Equal("http://identity/api/v1/auth/session", request.RequestUri!.ToString());
            Assert.Equal("Bearer", request.Headers.Authorization!.Scheme);
            Assert.Equal("fixture-token", request.Headers.Authorization.Parameter);
            return new(status);
        }))
        { BaseAddress = new Uri("http://identity/") };
        Assert.Equal(active, await new IdentitySessionClient(client).IsActiveAsync("fixture-token", default));
    }
    [Fact]
    public async Task Outage_is_not_a_revoked_session()
    {
        using var client = new HttpClient(new Handler(_ => new(HttpStatusCode.ServiceUnavailable))) { BaseAddress = new Uri("http://identity/") };
        await Assert.ThrowsAsync<HttpRequestException>(() => new IdentitySessionClient(client).IsActiveAsync("fixture-token", default));
    }
    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> action) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => Task.FromResult(action(request));
    }
}
