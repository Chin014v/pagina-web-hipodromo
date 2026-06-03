using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Facturacion
{
    public class DetalleModel : PageModel
    {
        private readonly IFacturacionRepositorio _repo;

        public DetalleModel(IFacturacionRepositorio repo)
        {
            _repo = repo;
        }

        public FacturaDetalleDTO? Factura { get; set; }

        public async Task<IActionResult> OnGetAsync(int id)
        {
            Factura = await _repo.ObtenerFacturaDetalleAsync(id);
            if (Factura == null) return NotFound();

            if (User.IsInRole("Propietario"))
            {
                var claim = User.FindFirst("PropietarioId");
                if (claim == null || !int.TryParse(claim.Value, out int idProp) || Factura.IdPropietario != idProp)
                {
                    return NotFound();
                }
            }

            return Page();
        }
    }
}
