using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using CareSitter.Modules.Booking.Application.BookingChat;
using CareSitter.Modules.Booking.Controllers;
using CareSitter.SharedKernel.Results;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CareSitter.IntegrationTests;

public sealed class BookingChatAdminAuthorizationTests
{
    [Fact]
    public async Task Non_admin_cannot_access_booking_chat_admin_api()
    {
        using var server = new TestServer(new WebHostBuilder()
            .ConfigureServices(services =>
            {
                services.AddSingleton<IBookingChatAdminService, UnreachableAdminService>();
                services.AddAuthentication("Test")
                    .AddScheme<AuthenticationSchemeOptions, RoleHeaderAuthenticationHandler>(
                        "Test", _ => { });
                services.AddAuthorization();
                services.AddControllers()
                    .AddApplicationPart(typeof(AdminBookingChatController).Assembly);
            })
            .Configure(app =>
            {
                app.UseRouting();
                app.UseAuthentication();
                app.UseAuthorization();
                app.UseEndpoints(endpoints => endpoints.MapControllers());
            }));
        using var client = server.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-Role", "CUSTOMER");

        using var response = await client.GetAsync("/api/v1/admin/booking-chats");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    private sealed class RoleHeaderAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers["X-Test-Role"].ToString();
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Role, role)
            };
            var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(
                new AuthenticationTicket(principal, Scheme.Name)));
        }
    }

    private sealed class UnreachableAdminService : IBookingChatAdminService
    {
        private static Task<T> Unreachable<T>() =>
            Task.FromException<T>(new InvalidOperationException(
                "Authorization must reject the request before invoking the service."));

        public Task<Result<BookingChatAdminListPage>> ListAsync(
            BookingChatAdminListFilter filter, string? cursor, int limit,
            CancellationToken ct = default) => Unreachable<Result<BookingChatAdminListPage>>();

        public Task<Result<BookingChatAdminDetail>> GetAsync(Guid conversationId,
            string reason, Guid? ticketId, CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminDetail>>();

        public Task<Result<BookingChatAdminMessagePage>> GetMessagesAsync(
            Guid conversationId, long? beforeSequence, int limit, string reason,
            Guid? ticketId, CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminMessagePage>>();

        public Task<Result<BookingChatAdminActivityPage>> GetActivityAsync(
            Guid conversationId, string? cursor, int limit,
            CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminActivityPage>>();

        public Task<Result<BookingChatAdminDetail>> BlockAsync(Guid conversationId,
            BookingChatAdminBlockRequest request, CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminDetail>>();

        public Task<Result<BookingChatAdminDetail>> UnblockAsync(Guid conversationId,
            BookingChatAdminBlockRequest request, CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminDetail>>();

        public Task<Result<BookingChatAdminDetail>> ReleaseLegalHoldAsync(
            Guid conversationId, BookingChatAdminBlockRequest request,
            CancellationToken ct = default) =>
            Unreachable<Result<BookingChatAdminDetail>>();
    }
}
