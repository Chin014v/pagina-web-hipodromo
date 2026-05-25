# Etapa de construcción
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copiar el archivo del proyecto y restaurar las dependencias
COPY ["HipodromoNacional.csproj", "./"]
RUN dotnet restore "HipodromoNacional.csproj"

# Copiar el resto del código y compilar
COPY . .
RUN dotnet publish "HipodromoNacional.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Etapa final (Runtime)
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 8080

# Establecer la variable de entorno para que escuche en el puerto que Render asigna
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "HipodromoNacional.dll"]
