using System.Data;
using Npgsql;
using HipodromoNacional.Repositorios;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages();

var connectionString = builder.Configuration.GetConnectionString("PostgresConnection");
builder.Services.AddScoped<IDbConnection>(sp => new NpgsqlConnection(connectionString));

builder.Services.AddScoped<IPropietarioRepositorio, PropietarioRepositorio>();
builder.Services.AddScoped<ICaballoRepositorio, CaballoRepositorio>();
builder.Services.AddScoped<IEventoRepositorio, EventoRepositorio>();
builder.Services.AddScoped<IEstabloRepositorio, EstabloRepositorio>();
builder.Services.AddScoped<IFacturacionRepositorio, FacturacionRepositorio>();

var app = builder.Build();



// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

app.Run();

