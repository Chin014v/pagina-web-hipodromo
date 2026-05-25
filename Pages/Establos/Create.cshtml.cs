using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Models;
using HipodromoNacional.Repositories;

namespace HipodromoNacional.Pages.Establos
{
    public class CreateModel : PageModel
    {
        private readonly IEstabloRepository _repo;

        public CreateModel(IEstabloRepository repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public EstabloDTO Establo { get; set; } = new();

        public void OnGet()
        {
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearEstabloAsync(Establo);
                TempData["SuccessMessage"] = "Establo registrado exitosamente.";
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
