using System.Net;
using System.Net.Http.Json;
using CareSitter.Nutrition.Infrastructure;

namespace CareSitter.Nutrition.Tests;

public sealed class PeopleClientTests
{
    [Fact]
    public async Task Internal_request_scopes_owner_and_credential_without_shared_database()
    {
        var owner = Guid.NewGuid(); var source = EligibilityTests.Healthy();
        var handler = new Handler(request =>
        {
            Assert.Equal($"http://people/internal/v1/nutrition/owners/{owner}/beneficiaries/{source.BeneficiaryId}/health-profile", request.RequestUri!.ToString());
            Assert.Equal("test-service-key", request.Headers.GetValues("X-Nutrition-Service-Key").Single());
            return new(HttpStatusCode.OK) { Content = JsonContent.Create(source) };
        });
        using var http = new HttpClient(handler) { BaseAddress = new Uri("http://people/") };
        http.DefaultRequestHeaders.Add("X-Nutrition-Service-Key", "test-service-key");
        Assert.Equal(source.Revision, (await new PeopleHealthClient(http).ReadAsync(owner, source.BeneficiaryId, default))!.Revision);
    }
    [Fact]
    public async Task Missing_is_not_outage_and_wrong_beneficiary_response_is_rejected()
    {
        using var http = new HttpClient(new Handler(_ => new(HttpStatusCode.NotFound))) { BaseAddress = new Uri("http://people/") };
        Assert.Null(await new PeopleHealthClient(http).ReadAsync(Guid.NewGuid(), Guid.NewGuid(), default));
        using var outage = new HttpClient(new Handler(_ => new(HttpStatusCode.ServiceUnavailable))) { BaseAddress = new Uri("http://people/") };
        await Assert.ThrowsAsync<HttpRequestException>(() => new PeopleHealthClient(outage).ReadAsync(Guid.NewGuid(), Guid.NewGuid(), default));
        using var mismatched = new HttpClient(new Handler(_ => new(HttpStatusCode.OK) { Content = JsonContent.Create(EligibilityTests.Healthy()) })) { BaseAddress = new Uri("http://people/") };
        await Assert.ThrowsAsync<HttpRequestException>(() => new PeopleHealthClient(mismatched).ReadAsync(Guid.NewGuid(), Guid.NewGuid(), default));
    }
    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct) => Task.FromResult(response(request));
    }
}
