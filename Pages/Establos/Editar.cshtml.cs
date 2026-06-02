using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Establos
{
    public class EditarModel : PageModel
    {
        private readonly IEstabloRepositorio _repo;

        public EditarModel(IEstabloRepositorio repo)
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
            ModelState.Remove("Establo.Codigo");

            if (!ModelState.IsValid) return Page();

            try
            {
                bool success = await _repo.ActualizarEstabloAsync(Establo);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el establo especificado o no hubo cambios.";
                    return Page();
                }
                TempData["SuccessMessage"] = "Establo actualizado exitosamente.";
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
