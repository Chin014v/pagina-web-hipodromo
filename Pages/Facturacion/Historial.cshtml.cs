using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace HipodromoNacional.Pages.Facturacion
{
    public class HistorialModel : PageModel
    {
        private readonly IFacturacionRepositorio _repo;

        public HistorialModel(IFacturacionRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<FacturaDetalleDTO> Facturas { get; set; } = new List<FacturaDetalleDTO>();

        public async Task OnGetAsync()
        {
            if (User.IsInRole("Propietario"))
            {
                var claim = User.FindFirst("PropietarioId");
                if (claim != null && int.TryParse(claim.Value, out int idProp))
                {
                    Facturas = await _repo.ObtenerTodasFacturasAsync(idProp);
                }
            }
            else
            {
                Facturas = await _repo.ObtenerTodasFacturasAsync();
            }
        }
    }
}
