using System.Data;
using Dapper;
using Npgsql;
using NpgsqlTypes;
using HipodromoNacional.Repositorios;

SqlMapper.AddTypeHandler(new TimeOnlyTypeHandler());

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
builder.Services.AddScoped<IInscripcionRepositorio, InscripcionRepositorio>();
builder.Services.AddScoped<IResultadoRepositorio, ResultadoRepositorio>();
builder.Services.AddScoped<IVeterinarioRepositorio, VeterinarioRepositorio>();
builder.Services.AddScoped<IAlertaRepositorio, AlertaRepositorio>();
builder.Services.AddScoped<ISuministroRepositorio, SuministroRepositorio>();
builder.Services.AddScoped<IAlimentacionRepositorio, AlimentacionRepositorio>();
builder.Services.AddScoped<IAsignacionEstabloRepositorio, AsignacionEstabloRepositorio>();
builder.Services.AddScoped<IProveedorRepositorio, ProveedorRepositorio>();
builder.Services.AddScoped<IBeneficioRepositorio, BeneficioRepositorio>();
builder.Services.AddScoped<IAuditoriaRepositorio, AuditoriaRepositorio>();

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

// Dapper TypeHandler para TimeOnly -> time without time zone en PostgreSQL
public class TimeOnlyTypeHandler : SqlMapper.TypeHandler<TimeOnly>
{
    public override void SetValue(IDbDataParameter parameter, TimeOnly value)
    {
        parameter.Value = value;
        if (parameter is NpgsqlParameter npgsqlParam)
            npgsqlParam.NpgsqlDbType = NpgsqlDbType.Time;
    }

    public override TimeOnly Parse(object value) => value switch
    {
        TimeOnly t => t,
        TimeSpan ts => TimeOnly.FromTimeSpan(ts),
        DateTime dt => TimeOnly.FromDateTime(dt),
        _ => TimeOnly.Parse(value.ToString()!)
    };
}

