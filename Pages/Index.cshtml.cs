using Microsoft.AspNetCore.Mvc.RazorPages;
using System.Data;
using Dapper;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages
{
    [Authorize]
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
                if (User.IsInRole("Propietario"))
                {
                    var claim = User.FindFirst("PropietarioId");
                    if (claim != null && int.TryParse(claim.Value, out int idProp))
                    {
                        CantidadCaballos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.caballo WHERE id_propietario = @IdProp", new { IdProp = idProp });
                    }
                    else
                    {
                        CantidadCaballos = 0;
                    }
                }
                else
                {
                    CantidadCaballos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.caballo");
                }

                if (User.IsInRole("Administrador"))
                {
                    CantidadPropietarios = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.propietario");
                    TotalFacturado = await _db.ExecuteScalarAsync<decimal>("SELECT COALESCE(SUM(total), 0) FROM public.factura");
                }
                else
                {
                    CantidadPropietarios = 0;
                    TotalFacturado = 0;
                }

                CantidadEventos = await _db.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM public.evento WHERE estado = 'Programado' OR estado = 'EnCurso'");
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
