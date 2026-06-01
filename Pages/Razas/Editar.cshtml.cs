using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Razas
{
    [Authorize(Roles = "Administrador")]
    public class EditarModel : PageModel
    {
        private readonly IRazaRepositorio _repo;

        public EditarModel(IRazaRepositorio repo)
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
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.ActualizarRazaAsync(Raza);
                TempData["SuccessMessage"] = "Raza actualizada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al actualizar: {ex.Message}");
                return Page();
            }
        }
    }
}
