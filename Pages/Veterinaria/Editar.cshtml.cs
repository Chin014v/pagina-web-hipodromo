using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Veterinaria
{
    public class EditarModel : PageModel
    {
        private readonly IVeterinarioRepositorio _repo;

        public EditarModel(IVeterinarioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public HistorialVeterinarioDTO Historial { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Historial = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Historial.IdCaballo");
            ModelState.Remove("Historial.IdVeterinario");
            ModelState.Remove("Historial.CodigoRegistro");
            ModelState.Remove("Historial.Diagnostico");
            ModelState.Remove("Historial.Tratamiento");
            ModelState.Remove("Historial.FechaRevision");
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.ActualizarHistorialAsync(Historial);
                TempData["SuccessMessage"] = "Registro veterinario actualizado exitosamente.";
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
