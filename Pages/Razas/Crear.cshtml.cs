using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Razas
{
    [Authorize(Roles = "Administrador")]
    public class CrearModel : PageModel
    {
        private readonly IRazaRepositorio _repo;

        public CrearModel(IRazaRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public RazaDTO Raza { get; set; } = new();

        public void OnGet()
        {
            Raza.Estado = "Activo";
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearRazaAsync(Raza);
                TempData["SuccessMessage"] = "Raza creada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                ModelState.AddModelError(string.Empty, $"Error al crear: {ex.Message}");
                return Page();
            }
        }
    }
}
