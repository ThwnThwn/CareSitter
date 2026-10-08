using CareSitter.Messaging.Contracts.Events;
using CareSitter.Messaging.Kafka;
using CareSitter.NotificationWorker.Application.Commands.Notifications.DeliverNotification;
using CareSitter.NotificationWorker.Application.Ports;
using CareSitter.NotificationWorker.Infrastructure.Clients;
using CareSitter.NotificationWorker.Infrastructure.Delivery;

var builder = WebApplication.CreateBuilder(args);
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.Warning);
builder.Services.AddKafkaMessaging(builder.Configuration, (registry, options) =>
    registry.Add<NotificationRequested>("caresitter.notifications.requested", 1, options.NotificationsTopic));
var kafka = CareSitter.Messaging.Kafka.Configuration.KafkaOptions.Read(builder.Configuration);
if (!kafka.Enabled || !kafka.NotificationsEnabled)
    throw new InvalidOperationException("NotificationWorker requires KAFKA_ENABLED and KAFKA_FLOW_NOTIFICATIONS_ENABLED.");
var serviceKey = builder.Configuration["KAFKA_INTERNAL_SERVICE_KEY"];
var apiAddress = builder.Configuration["KAFKA_SUPPORT_API_URL"];
if (serviceKey?.Length is not (>= 32 and <= 256) || !Uri.TryCreate(apiAddress, UriKind.Absolute, out var apiUri) ||
    apiUri.Scheme is not ("http" or "https"))
    throw new InvalidOperationException("KAFKA_INTERNAL_SERVICE_KEY and KAFKA_SUPPORT_API_URL must be configured.");
builder.Services.AddHttpClient<INotificationDeliveryClient, SupportNotificationClient>(http =>
{
    http.BaseAddress = apiUri;
    http.Timeout = TimeSpan.FromSeconds(10);
    http.DefaultRequestHeaders.Add("X-Messaging-Service-Key", serviceKey);
});
builder.Services.AddScoped<INotificationSender, NotificationSender>();
builder.Services.AddKafkaConsumer(kafka.ConsumerGroup, consumer =>
{
    consumer.Subscribe(kafka.NotificationsTopic);
    consumer.AddHandler<NotificationRequested, DeliverNotificationHandler>(builder.Services);
});
var app = builder.Build();
app.MapGet("/health/live", () => Results.Ok(new { status = "alive" }));
app.MapHealthChecks("/health/ready");
app.Run();
