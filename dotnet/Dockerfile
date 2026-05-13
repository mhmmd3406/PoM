# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Restore dependencies first (layer cache)
COPY src/PoM.B2B.Api/PoM.B2B.Api.csproj ./PoM.B2B.Api/
RUN dotnet restore ./PoM.B2B.Api/PoM.B2B.Api.csproj

# Copy source and publish
COPY src/PoM.B2B.Api/ ./PoM.B2B.Api/
RUN dotnet publish ./PoM.B2B.Api/PoM.B2B.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore \
    /p:UseAppHost=false

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app

# Non-root user — security best practice
RUN addgroup -S pomgroup && adduser -S pomuser -G pomgroup
USER pomuser

COPY --from=build --chown=pomuser:pomgroup /app/publish .

# Cloud Run injects PORT env var; ASP.NET Core reads it via ASPNETCORE_URLS
ENV ASPNETCORE_URLS=http://+:${PORT:-8080}
EXPOSE 8080

ENTRYPOINT ["dotnet", "PoM.B2B.Api.dll"]
