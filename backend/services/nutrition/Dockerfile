FROM mcr.microsoft.com/dotnet/sdk:8.0.425 AS build
WORKDIR /src
COPY src/CareSitter.Nutrition/CareSitter.Nutrition.csproj ./CareSitter.Nutrition/
RUN dotnet restore ./CareSitter.Nutrition/CareSitter.Nutrition.csproj
COPY src/CareSitter.Nutrition/ ./CareSitter.Nutrition/
RUN dotnet publish ./CareSitter.Nutrition/CareSitter.Nutrition.csproj -c Release -o /out --no-restore
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /out ./
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "CareSitter.Nutrition.dll"]
