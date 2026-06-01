using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Veterinaria
{
    public class EliminarModel : PageModel
    {
        private readonly IVeterinarioRepositorio _repo;

        public EliminarModel(IVeterinarioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public HistorialVeterinarioDTO Historial { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Historial = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarHistorialAsync(Historial.IdHistorial);
                TempData["SuccessMessage"] = "Registro veterinario eliminado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al eliminar: {ex.Message}";
                return RedirectToPage("./Index");
            }
        }
    }
}
