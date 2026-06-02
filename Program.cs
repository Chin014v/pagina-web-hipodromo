using System.Data;
using Dapper;
using Npgsql;
using NpgsqlTypes;
using HipodromoNacional.Repositorios;

SqlMapper.AddTypeHandler(new TimeOnlyTypeHandler());

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddHttpContextAccessor();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("AdministradorOnly", policy => policy.RequireRole("Administrador"));
    options.AddPolicy("AdminOrVet", policy => policy.RequireRole("Administrador", "Veterinario"));
    options.AddPolicy("AdminOrEstablo", policy => policy.RequireRole("Administrador", "Encargado de Establo"));
    options.AddPolicy("AdminOrProp", policy => policy.RequireRole("Administrador", "Propietario"));
});

builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/Auditoria", "AdministradorOnly");
    options.Conventions.AuthorizeFolder("/Usuarios", "AdministradorOnly");
    options.Conventions.AuthorizeFolder("/Propietarios", "AdministradorOnly");
    options.Conventions.AuthorizeFolder("/Razas", "AdministradorOnly");
    
    options.Conventions.AuthorizeFolder("/Alertas", "AdminOrVet");
    options.Conventions.AuthorizeFolder("/Veterinaria", "AdminOrVet");
    
    options.Conventions.AuthorizeFolder("/EstablosMgt", "AdminOrEstablo");
    options.Conventions.AuthorizeFolder("/EstablosMgt/Beneficios", "AdministradorOnly");
    
    options.Conventions.AuthorizeFolder("/Establos", "AdminOrEstablo");
    options.Conventions.AuthorizePage("/Establos/Crear", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Establos/Editar", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Establos/Eliminar", "AdministradorOnly");
    
    options.Conventions.AuthorizeFolder("/Caballos");
    options.Conventions.AuthorizePage("/Caballos/Crear", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Caballos/Editar", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Caballos/Eliminar", "AdministradorOnly");
    
    options.Conventions.AuthorizeFolder("/Eventos");
    options.Conventions.AuthorizePage("/Eventos/Crear", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Eventos/Editar", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Eventos/Eliminar", "AdministradorOnly");

    options.Conventions.AuthorizeFolder("/Resultados");
    options.Conventions.AuthorizePage("/Resultados/Crear", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Resultados/Editar", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Resultados/Eliminar", "AdministradorOnly");

    options.Conventions.AuthorizeFolder("/Inscripciones");
    options.Conventions.AuthorizePage("/Inscripciones/Crear", "AdminOrProp");
    options.Conventions.AuthorizePage("/Inscripciones/Editar", "AdminOrProp");
    options.Conventions.AuthorizePage("/Inscripciones/Eliminar", "AdministradorOnly");
    
    options.Conventions.AuthorizePage("/Facturacion/EmitirFactura", "AdministradorOnly");
    options.Conventions.AuthorizePage("/Facturacion/Historial", "AdminOrProp");
    options.Conventions.AuthorizePage("/Facturacion/Detalle", "AdminOrProp");
    options.Conventions.AuthorizeFolder("/Estadisticas", "AdministradorOnly");
});

var connectionString = builder.Configuration.GetConnectionString("PostgresConnection");
builder.Services.AddScoped<IDbConnection>(sp =>
{
    var httpContextAccessor = sp.GetRequiredService<IHttpContextAccessor>();
    var username = httpContextAccessor.HttpContext?.User?.Identity?.Name ?? "admin";
    var connBuilder = new Npgsql.NpgsqlConnectionStringBuilder(connectionString)
    {
        ApplicationName = username
    };
    return new NpgsqlConnection(connBuilder.ConnectionString);
});

// Autenticación por Cookies
builder.Services.AddAuthentication(Microsoft.AspNetCore.Authentication.Cookies.CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Login";
        options.LogoutPath = "/Logout";
        options.AccessDeniedPath = "/Error";
        options.ExpireTimeSpan = TimeSpan.FromMinutes(60);
    });

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
builder.Services.AddScoped<IUsuarioRepositorio, UsuarioRepositorio>();
builder.Services.AddScoped<IRazaRepositorio, RazaRepositorio>();

var app = builder.Build();

// Run DB Initializer
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<IDbConnection>();
    var env = scope.ServiceProvider.GetRequiredService<IWebHostEnvironment>();
    DbInitializer.Initialize(db, env.ContentRootPath);
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthentication();
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

