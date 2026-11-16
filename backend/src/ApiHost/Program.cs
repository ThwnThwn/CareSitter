using CareSitter.ApiHost.Health;
using CareSitter.ApiHost.Jobs;
using CareSitter.ApiHost.Realtime;
using CareSitter.ApiHost.Startup;

var backfillRequested = args.Contains(BookingChatBackfill.Argument, StringComparer.Ordinal);
var hostArgs = backfillRequested
    ? args.Where(arg => arg != BookingChatBackfill.Argument).ToArray()
    : args;

var builder = ApiServiceExtensions.CreateBuilder(hostArgs);
builder.AddCareSitterApi();
var hangfire = HangfireStartup.Configure(builder);
var app = builder.Build();

if (backfillRequested)
{
    await BookingChatBackfill.RunAsync(app.Services);
    return;
}

await hangfire.VerifyStorageAsync();
app.UseApiPipeline();
app.MapApiHealthEndpoints();
app.MapApiHubs();
HangfireStartup.UseDashboardAndScheduleJobs(app);
app.MapApiEndpoints();
app.Run();

public partial class Program;
