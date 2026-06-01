using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Razas
{
    [Authorize(Roles = "Administrador")]
    public class EliminarModel : PageModel
    {
        private readonly IRazaRepositorio _repo;

        public EliminarModel(IRazaRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public RazaDTO Raza { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var r = await _repo.ObtenerPorIdAsync(id);
            if (r == null) return NotFound();

            Raza = r;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarRazaAsync(Raza.IdRaza);
                TempData["SuccessMessage"] = "Raza eliminada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al eliminar: {ex.Message}. Asegúrese de que no haya caballos registrados bajo esta raza.");
                return Page();
            }
        }
    }
}
