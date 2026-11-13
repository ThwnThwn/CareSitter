using Confluent.Kafka;

namespace CareSitter.Nutrition.Infrastructure;

/// <summary>Commits a broker offset only after the Nutrition transaction or DLQ publish.</summary>
internal sealed class BeneficiaryDeletionConsumer(
    IConfiguration configuration, BeneficiaryDeletionProcessor processor,
    ILogger<BeneficiaryDeletionConsumer> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var bootstrap = configuration["BeneficiaryEvents:BootstrapServers"]!;
        var topic = configuration["BeneficiaryEvents:Topic"]!;
        var group = configuration["BeneficiaryEvents:ConsumerGroup"]!;
        var dlq = configuration["BeneficiaryEvents:DlqTopic"]!;
        using var consumer = new ConsumerBuilder<string, string>(new ConsumerConfig
        {
            BootstrapServers = bootstrap, GroupId = group, ClientId = "caresitter-nutrition",
            AutoOffsetReset = AutoOffsetReset.Earliest, EnableAutoCommit = false,
            EnableAutoOffsetStore = false, MaxPollIntervalMs = 300000
        }).Build();
        using var deadLetters = new ProducerBuilder<string, string>(new ProducerConfig
        {
            BootstrapServers = bootstrap, ClientId = "caresitter-nutrition-dlq",
            EnableIdempotence = true, Acks = Acks.All
        }).Build();
        consumer.Subscribe(topic);
        var consecutiveFailures = 0;
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var record = consumer.Consume(stoppingToken);
                if (record?.Message?.Value is null) continue;
                try
                {
                    var value = BeneficiaryDeletionProcessor.Parse(record.Message.Value,
                        record.Message.Key ?? "", out var eventId);
                    if (value is not null) await processor.PurgeAsync(eventId, value, stoppingToken);
                }
                catch (Exception error) when (error is InvalidDataException or System.Text.Json.JsonException)
                {
                    // Preserve the original wire record for controlled replay. Publishing must
                    // succeed before skipping poison; no payload is written to application logs.
                    await deadLetters.ProduceAsync(dlq, new Message<string, string>
                    {
                        Key = record.Message.Key ?? "", Value = record.Message.Value
                    }, stoppingToken);
                    logger.LogWarning("Invalid beneficiary event sent to DLQ at {Offset}.", record.TopicPartitionOffset);
                }
                consumer.Commit(record);
                consecutiveFailures = 0;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception error)
            {
                logger.LogError(error, "Beneficiary event delivery failed; offset remains uncommitted.");
                consecutiveFailures = Math.Min(consecutiveFailures + 1, 5);
                await Task.Delay(TimeSpan.FromSeconds(1 << consecutiveFailures), stoppingToken);
            }
        }
        consumer.Close();
    }
}
