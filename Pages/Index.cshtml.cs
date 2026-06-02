using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Data;
using Dapper;
using System.Threading.Tasks;

namespace HipodromoNacional.Pages
{
    public class IndexModel : PageModel
    {
        private readonly IDbConnection _db;

        public IndexModel(IDbConnection db)
        {
            _db = db;
        }

        public int CantidadCaballos { get; set; }
        public int CantidadPropietarios { get; set; }
        public int CantidadEventos { get; set; }
        public decimal TotalFacturado { get; set; }

        public async Task OnGetAsync()
        {
            try
            {
                CantidadCaballos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.caballo");
                CantidadPropietarios = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.propietario");
                CantidadEventos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.evento WHERE estado = 'Programado' OR estado = 'EnCurso'");
                TotalFacturado = await _db.ExecuteScalarAsync<decimal>("SELECT COALESCE(SUM(total), 0) FROM public.factura");
            }
            catch
            {
                CantidadCaballos = 0;
                CantidadPropietarios = 0;
                CantidadEventos = 0;
                TotalFacturado = 0;
            }
        }
    }
}
