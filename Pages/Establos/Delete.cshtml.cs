using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Establos
{
    public class DeleteModel : PageModel
    {
        private readonly IEstabloRepository _repo;

        public DeleteModel(IEstabloRepository repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public EstabloDTO Establo { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var e = await _repo.ObtenerPorIdAsync(id);
            if (e == null) return NotFound();

            Establo = e;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarEstabloAsync(Establo.IdEstablo);
                TempData["SuccessMessage"] = "Establo eliminado exitosamente.";
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
