using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using CareSitter.Nutrition.Contracts;

namespace CareSitter.Nutrition.Tests;

public sealed class ServiceAuthenticationTests
{
    [Fact]
    public async Task Separate_host_validates_customer_role_expiry_and_signature()
    {
        var secret = Guid.NewGuid().ToString("N") + Guid.NewGuid().ToString("N");
        var identity = new Identity();
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(web =>
        {
            web.UseSetting("Jwt:SecretKey", secret);
            web.UseSetting("Jwt:Issuer", "nutrition-test-issuer");
            web.UseSetting("Jwt:Audience", "nutrition-test-audience");
            web.UseSetting("People:BaseUrl", "https://people.example.test/");
            web.UseSetting("People:ServiceKey", Guid.NewGuid().ToString("N"));
            web.UseSetting("ConnectionStrings:Nutrition", "Host=127.0.0.1;Port=1;Database=unused;Username=unused");
            web.ConfigureServices(services => { services.RemoveAll<IIdentitySessionClient>(); services.AddSingleton<IIdentitySessionClient>(identity); });
        });
        using var client = factory.CreateClient();
        const string path = "/api/v1/nutrition/capabilities";
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync(path)).StatusCode);
        async Task<HttpStatusCode> CallAsync(string role, string key, DateTime expires)
        {
            var jwt = new JwtSecurityToken("nutrition-test-issuer", "nutrition-test-audience",
                [new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()), new Claim(ClaimTypes.Role, role),
                 new Claim("sid",Guid.NewGuid().ToString()),new Claim("jti",Guid.NewGuid().ToString())],
                notBefore: DateTime.UtcNow.AddHours(-1), expires: expires,
                signingCredentials: new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)), SecurityAlgorithms.HmacSha256));
            client.DefaultRequestHeaders.Authorization = new("Bearer", new JwtSecurityTokenHandler().WriteToken(jwt));
            return (await client.GetAsync(path)).StatusCode;
        }
        Assert.Equal(HttpStatusCode.OK, await CallAsync("CUSTOMER", secret, DateTime.UtcNow.AddMinutes(10)));
        Assert.Equal(HttpStatusCode.Forbidden, await CallAsync("CAREGIVER", secret, DateTime.UtcNow.AddMinutes(10)));
        Assert.Equal(HttpStatusCode.Unauthorized, await CallAsync("CUSTOMER", secret, DateTime.UtcNow.AddMinutes(-5)));
        Assert.Equal(HttpStatusCode.Unauthorized, await CallAsync("CUSTOMER", Guid.NewGuid().ToString("N"), DateTime.UtcNow.AddMinutes(10)));
        identity.Active = false;
        Assert.Equal(HttpStatusCode.Unauthorized, await CallAsync("CUSTOMER", secret, DateTime.UtcNow.AddMinutes(10)));
        identity.Unavailable = true;
        Assert.Equal(HttpStatusCode.ServiceUnavailable, await CallAsync("CUSTOMER", secret, DateTime.UtcNow.AddMinutes(10)));
    }
    private sealed class Identity : IIdentitySessionClient
    {
        public bool Active = true, Unavailable;
        public Task<bool> IsActiveAsync(string bearerToken, CancellationToken ct) => Unavailable
            ? throw new HttpRequestException() : Task.FromResult(Active);
    }
}
