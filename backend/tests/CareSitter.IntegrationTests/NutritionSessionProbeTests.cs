using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Text;
using CareSitter.Contracts.Services;
using CareSitter.Infrastructure.Auth;
using CareSitter.Modules.Identity.Controllers;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using System.Threading.RateLimiting;

namespace CareSitter.IntegrationTests;

public sealed class NutritionSessionProbeTests
{
    [Fact]
    public async Task Session_probe_reuses_durable_identity_validation_and_returns_no_profile()
    {
        var key=Guid.NewGuid().ToString("N")+Guid.NewGuid().ToString("N");
        var validator=new Validator();
        using var host=await new HostBuilder().ConfigureWebHost(web=>web.UseTestServer().ConfigureServices(services=>
        {
            services.AddLogging();
            services.AddJwtAuthentication(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string,string?>
                {{"Jwt:SecretKey",key},{"Jwt:Issuer","fixture"},{"Jwt:Audience","fixture"}}).Build());
            services.AddSingleton<IAccessSessionValidator>(validator);
            services.AddMediatR(c=>c.RegisterServicesFromAssemblyContaining<AuthController>());
            services.AddControllers().AddApplicationPart(typeof(AuthController).Assembly);
            services.AddRateLimiter(options=>options.AddFixedWindowLimiter("auth-session",o=>
                {o.PermitLimit=120;o.Window=TimeSpan.FromMinutes(1);}));
        }).Configure(app=>
        {
            app.UseRouting();app.UseAuthentication();app.UseAuthorization();app.UseRateLimiter();
            app.UseEndpoints(endpoints=>endpoints.MapControllers());
        })).StartAsync();
        using var client=host.GetTestClient();
        Assert.Equal(HttpStatusCode.Unauthorized,(await client.GetAsync("/api/v1/auth/session")).StatusCode);
        var user=Guid.NewGuid();var session=Guid.NewGuid();
        var jwt=new JwtSecurityToken("fixture","fixture",
            [new Claim(ClaimTypes.NameIdentifier,user.ToString()),new Claim("sid",session.ToString()),new Claim("jti",Guid.NewGuid().ToString())],
            expires:DateTime.UtcNow.AddMinutes(10),signingCredentials:new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key)),SecurityAlgorithms.HmacSha256));
        client.DefaultRequestHeaders.Authorization=new("Bearer",new JwtSecurityTokenHandler().WriteToken(jwt));
        var response=await client.GetAsync("/api/v1/auth/session");
        Assert.Equal(HttpStatusCode.NoContent,response.StatusCode);Assert.Empty(await response.Content.ReadAsStringAsync());
        Assert.Equal((user,session),validator.Last);
        validator.Active=false;
        Assert.Equal(HttpStatusCode.Unauthorized,(await client.GetAsync("/api/v1/auth/session")).StatusCode);
    }
    private sealed class Validator:IAccessSessionValidator
    {
        public bool Active=true;public (Guid,Guid) Last;
        public Task<bool> IsActiveAsync(Guid userId,Guid sessionId,CancellationToken ct=default)
        {Last=(userId,sessionId);return Task.FromResult(Active);}
    }
}
