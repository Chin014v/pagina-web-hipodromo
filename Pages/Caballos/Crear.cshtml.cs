using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Caballos
{
    public class CrearModel : PageModel
    {
        private readonly ICaballoRepositorio _repo;

        public CrearModel(ICaballoRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public CaballoDTO Caballo { get; set; } = new();

        public void OnGet()
        {
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearCaballoAsync(Caballo);
                TempData["SuccessMessage"] = "Caballo registrado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                return Page();
            }
        }
    }
}
