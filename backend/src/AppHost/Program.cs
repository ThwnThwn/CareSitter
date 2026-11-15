using CareSitter.AppHost;
using CareSitter.AppHost.Extensions;

var builder = DistributedApplication.CreateBuilder(args);
var settings = AppHostSettings.Load(builder, args);

var api = builder.AddCareSitterApi(settings);
var nutrition = await builder.AddNutritionServiceAsync(settings, api);
api.WaitFor(nutrition);
builder.AddNotificationWorker(settings, api);

builder.Build().Run();
