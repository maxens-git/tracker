# Build Angular frontend
FROM node:22-bookworm AS frontend-builder
WORKDIR /app/web
COPY web/package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --no-audit --omit=optional; else npm install --no-audit --omit=optional; fi
COPY web/ ./
RUN npm run build

# Build .NET backend and bundle frontend assets
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS backend-builder
WORKDIR /src
COPY TrackerApi.csproj ./
RUN dotnet restore
COPY . ./
COPY --from=frontend-builder /app/web/dist/tracker/browser ./wwwroot
RUN dotnet publish TrackerApi.csproj -c Release -o /app/publish /p:UseAppHost=false

# Final image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=backend-builder /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "TrackerApi.dll"]
