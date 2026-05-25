using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Repositories;
using System.Threading.Tasks;
using System;

namespace HipodromoNacional.Pages.Facturacion
{
    public class EmitirFacturaModel : PageModel
    {
        private readonly IFacturacionRepository _repo;

        public EmitirFacturaModel(IFacturacionRepository repo)
        {
            _repo = repo;
        }

        public void OnGet()
        {
        }

        public async Task<IActionResult> OnPostCalcularFrecuentesAsync()
        {
            try
            {
                await _repo.EjecutarCalculoFrecuentesAsync();
                TempData["SuccessMessage"] = "Descuentos de propietarios frecuentes aplicados correctamente.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Ocurrió un error al ejecutar el batch: {ex.Message}";
            }
            
            return RedirectToPage();
        }
    }
}
