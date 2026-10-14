FROM mcr.microsoft.com/dotnet/sdk:8.0.425 AS build
WORKDIR /src
COPY src/CareSitter.Nutrition/CareSitter.Nutrition.csproj ./src/CareSitter.Nutrition/
COPY protos/ ./protos/
RUN dotnet restore ./src/CareSitter.Nutrition/CareSitter.Nutrition.csproj
COPY src/CareSitter.Nutrition/ ./src/CareSitter.Nutrition/
RUN dotnet publish ./src/CareSitter.Nutrition/CareSitter.Nutrition.csproj -c Release -o /out --no-restore
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /out ./
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080 8081
ENTRYPOINT ["dotnet", "CareSitter.Nutrition.dll"]
