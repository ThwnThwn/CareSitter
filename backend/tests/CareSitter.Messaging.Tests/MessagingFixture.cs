using Confluent.Kafka;
using System.Net;
using System.Net.Sockets;
using Testcontainers.Kafka;
using Testcontainers.PostgreSql;

namespace CareSitter.Messaging.Tests;

public sealed class MessagingFixture : IAsyncLifetime
{
    public KafkaContainer Kafka { get; } = new KafkaBuilder().WithImage("apache/kafka:3.9.1").WithKRaft()
        // Keep the advertised host port stable when Docker restarts the same container.
        .WithPortBinding(FindAvailablePort(), 9092)
        .WithEnvironment("KAFKA_AUTO_CREATE_TOPICS_ENABLE", "false")
        .WithEnvironment("KAFKA_HEAP_OPTS", "-Xms128m -Xmx256m").Build();
    public PostgreSqlContainer Postgres { get; } = new PostgreSqlBuilder().WithImage("postgres:16-alpine").Build();

    public async Task InitializeAsync() => await Task.WhenAll(Kafka.StartAsync(), Postgres.StartAsync());
    public async Task DisposeAsync() { await Kafka.DisposeAsync(); await Postgres.DisposeAsync(); }

    private static int FindAvailablePort()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        return ((IPEndPoint)listener.LocalEndpoint).Port;
    }

    public async Task<string> CreateTopicAsync()
    {
        var topic = "messaging-test-" + Guid.NewGuid().ToString("N");
        using var admin = new AdminClientBuilder(new AdminClientConfig { BootstrapServers = Kafka.GetBootstrapAddress() }).Build();
        await admin.CreateTopicsAsync([
            new Confluent.Kafka.Admin.TopicSpecification { Name = topic, NumPartitions = 3, ReplicationFactor = 1 },
            new Confluent.Kafka.Admin.TopicSpecification { Name = topic + ".dlq", NumPartitions = 1, ReplicationFactor = 1 }
        ]);
        return topic;
    }
}
