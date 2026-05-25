using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Caballos
{
    public class EditModel : PageModel
    {
        private readonly ICaballoRepository _repo;

        public EditModel(ICaballoRepository repo)
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
                await _repo.ActualizarCaballoAsync(Caballo);
                TempData["SuccessMessage"] = "Caballo actualizado exitosamente.";
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
