using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Alertas
{
    public class EditarModel : PageModel
    {
        private readonly IAlertaRepositorio _repo;

        public EditarModel(IAlertaRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public AlertaCertificacionDTO Alerta { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Alerta = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.ActualizarAlertaAsync(Alerta.IdAlerta, Alerta.Estado, Alerta.Mensaje, Alerta.FechaAlerta);
                TempData["SuccessMessage"] = "Alerta actualizada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al actualizar: {ex.Message}";
                return Page();
            }
        }
    }
}
