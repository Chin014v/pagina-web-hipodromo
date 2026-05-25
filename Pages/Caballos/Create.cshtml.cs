using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Caballos
{
    public class CreateModel : PageModel
    {
        private readonly ICaballoRepository _repo;

        public CreateModel(ICaballoRepository repo)
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
