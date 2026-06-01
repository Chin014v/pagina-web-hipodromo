using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Alimentacion
{
    public class EditarModel : PageModel
    {
        private readonly IAlimentacionRepositorio _repo;

        public EditarModel(IAlimentacionRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public AlimentacionDTO Alimentacion { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Alimentacion = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.ActualizarAlimentacionAsync(Alimentacion);
                TempData["SuccessMessage"] = "Alimentación actualizada exitosamente.";
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
