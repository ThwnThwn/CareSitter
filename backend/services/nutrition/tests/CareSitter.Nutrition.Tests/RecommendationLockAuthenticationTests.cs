using System.Net;
using System.Net.Sockets;
using System.Buffers.Binary;
using System.Text;
using CareSitter.Nutrition.Infrastructure;
using Npgsql;

namespace CareSitter.Nutrition.Tests;

public sealed class RecommendationLockAuthenticationTests
{
    [Fact]
    public async Task Recommendation_lock_preserves_configured_password_without_exposing_it()
    {
        using var server = new TcpListener(IPAddress.Loopback, 0);
        server.Start();
        using var deadline = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var password = Guid.NewGuid().ToString("N");
        var settings = new NpgsqlConnectionStringBuilder
        {
            Host = "127.0.0.1", Port = ((IPEndPoint)server.LocalEndpoint).Port,
            Database = "fixture", Username = "fixture", Password = password,
            SslMode = SslMode.Disable, Pooling = false, Timeout = 3
        };
        await using var source = NpgsqlDataSource.Create(settings.ConnectionString);
        Assert.True(string.IsNullOrEmpty(new NpgsqlConnectionStringBuilder(source.ConnectionString).Password));
        var observed = ObserveAuthenticationAsync();
        await using var locks = new RecommendationLockDataSource(settings.ConnectionString);
        var store = new NutritionStore(source, locks);
        await Record.ExceptionAsync(() => store.InRecommendationScopeAsync(Guid.NewGuid(), Guid.NewGuid(),
            () => Task.FromResult(true), deadline.Token));
        Assert.True(await observed, "The recommendation lock connection must retain the configured password.");

        async Task<bool> ObserveAuthenticationAsync()
        {
            using var client = await server.AcceptTcpClientAsync(deadline.Token);
            await using var stream = client.GetStream();
            var length = new byte[4];
            await stream.ReadExactlyAsync(length, deadline.Token);
            var startup = new byte[BinaryPrimitives.ReadInt32BigEndian(length) - 4];
            await stream.ReadExactlyAsync(startup, deadline.Token);
            // PostgreSQL AuthenticationCleartextPassword. This loopback-only protocol fixture
            // observes the actual lock connection, independently of the DB test server's trust auth.
            await stream.WriteAsync(new byte[] { (byte)'R', 0, 0, 0, 8, 0, 0, 0, 3 }, deadline.Token);
            var type = new byte[1];
            if (await stream.ReadAsync(type, deadline.Token) == 0) return false;
            await stream.ReadExactlyAsync(length, deadline.Token);
            var response = new byte[BinaryPrimitives.ReadInt32BigEndian(length) - 4];
            await stream.ReadExactlyAsync(response, deadline.Token);
            return type[0] == (byte)'p' && Encoding.UTF8.GetString(response).TrimEnd('\0') == password;
        }
    }
}

