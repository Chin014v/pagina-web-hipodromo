using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Asignacion
{
    public class EliminarModel : PageModel
    {
        private readonly IAsignacionEstabloRepositorio _repo;

        public EliminarModel(IAsignacionEstabloRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public AsignacionEstabloDTO Asignacion { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Asignacion = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarAsignacionAsync(Asignacion.IdAsignacion);
                TempData["SuccessMessage"] = "Asignación eliminada exitosamente.";
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
