using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Caballos
{
    public class DeleteModel : PageModel
    {
        private readonly ICaballoRepository _repo;

        public DeleteModel(ICaballoRepository repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public CaballoDTO Caballo { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var c = await _repo.ObtenerPorIdAsync(id);
            if (c == null) return NotFound();

            Caballo = c;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarCaballoAsync(Caballo.IdCaballo);
                TempData["SuccessMessage"] = "Caballo eliminado exitosamente.";
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
