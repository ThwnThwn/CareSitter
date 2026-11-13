FROM mcr.microsoft.com/dotnet/sdk:8.0.425 AS build
WORKDIR /src
COPY src/CareSitter.Nutrition/ ./src/CareSitter.Nutrition/
COPY protos/ ./protos/
COPY tools/CareSitter.Nutrition.CatalogTool/ ./tools/CareSitter.Nutrition.CatalogTool/
RUN dotnet publish tools/CareSitter.Nutrition.CatalogTool/CareSitter.Nutrition.CatalogTool.csproj -c Release -o /out
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /out ./
USER $APP_UID
ENTRYPOINT ["dotnet", "CareSitter.Nutrition.CatalogTool.dll"]
