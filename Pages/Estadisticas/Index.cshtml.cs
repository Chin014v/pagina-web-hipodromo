using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.AspNetCore.Authorization;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Estadisticas
{
    public class IndexModel : PageModel
    {
        private readonly IDbConnection _db;

        public IndexModel(IDbConnection db)
        {
            _db = db;
        }

        // Estadísticas generales
        public int TotalCaballos { get; set; }
        public int TotalPropietarios { get; set; }
        public int TotalEventos { get; set; }
        public decimal TotalIngresos { get; set; }

        // Rankings
        public IEnumerable<dynamic> CaballosGanadores { get; set; } = new List<dynamic>();
        public IEnumerable<dynamic> PropietariosInversion { get; set; } = new List<dynamic>();
        public IEnumerable<dynamic> RazasFrecuentes { get; set; } = new List<dynamic>();

        public async Task OnGetAsync()
        {
            TotalCaballos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM caballo");
            TotalPropietarios = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM propietario");
            TotalEventos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM evento");
            TotalIngresos = await _db.ExecuteScalarAsync<decimal>("SELECT COALESCE(SUM(total), 0) FROM factura WHERE id_estado_pago = 2");

            CaballosGanadores = await _db.QueryAsync(@"
                SELECT c.nombre AS Caballo, p.nombre || ' ' || p.apellido1 AS Propietario, COUNT(rc.id_resultado) AS Victorias, SUM(rc.premio_obtenido) AS TotalPremios
                FROM resultado_carrera rc
                JOIN inscripcion i ON rc.id_inscripcion = i.id_inscripcion
                JOIN caballo c ON i.id_caballo = c.id_caballo
                JOIN propietario p ON c.id_propietario = p.id_propietario
                WHERE rc.posicion = 1
                GROUP BY c.nombre, p.nombre, p.apellido1
                ORDER BY Victorias DESC, TotalPremios DESC
                LIMIT 5");

            PropietariosInversion = await _db.QueryAsync(@"
                SELECT p.nombre || ' ' || p.apellido1 AS Propietario, p.cedula AS Cedula, COUNT(f.id_factura) AS FacturasEmitidas, SUM(f.total) AS TotalFacturado
                FROM factura f
                JOIN propietario p ON f.id_propietario = p.id_propietario
                GROUP BY p.nombre, p.apellido1, p.cedula
                ORDER BY TotalFacturado DESC
                LIMIT 5");

            RazasFrecuentes = await _db.QueryAsync(@"
                SELECT r.nombre_raza AS Raza, COUNT(c.id_caballo) AS Cantidad
                FROM caballo c
                JOIN raza r ON c.id_raza = r.id_raza
                GROUP BY r.nombre_raza
                ORDER BY Cantidad DESC
                LIMIT 5");
        }
    }
}
