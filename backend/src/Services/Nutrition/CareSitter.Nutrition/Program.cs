using CareSitter.Nutrition.Infrastructure;
using CareSitter.Nutrition.Startup;

var builder = WebApplication.CreateBuilder(args);
builder.Configuration.LoadEnv(builder.Environment);
var localDemoCatalog = LocalDemoCatalogOptions.From(builder.Configuration, builder.Environment);
builder.AddNutritionServices(localDemoCatalog);

var app = builder.Build();
app.UseNutritionPipeline();
app.MapNutritionEndpoints(localDemoCatalog);
app.Run();

public partial class Program;
