using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Beneficios
{
    public class EditarModel : PageModel
    {
        private readonly IBeneficioRepositorio _repo;

        public EditarModel(IBeneficioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public BeneficioPropietarioDTO Beneficio { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Beneficio = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.ActualizarBeneficioAsync(Beneficio);
                TempData["SuccessMessage"] = "Beneficio actualizado exitosamente.";
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
