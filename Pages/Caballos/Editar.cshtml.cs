using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Caballos
{
    public class EditarModel : PageModel
    {
        private readonly ICaballoRepositorio _repo;

        public EditarModel(ICaballoRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public CaballoDTO Caballo { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var c = await _repo.ObtenerPorIdAsync(id);
            if (c == null) return NotFound();

            Caballo = c;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Caballo.CodigoUnico");
            ModelState.Remove("Caballo.Sexo");
            ModelState.Remove("Caballo.IdRaza");
            ModelState.Remove("Caballo.IdPropietario");

            if (!ModelState.IsValid) return Page();

            try
            {
                bool success = await _repo.ActualizarCaballoAsync(Caballo);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el caballo especificado o no hubo cambios.";
                    return Page();
                }
                TempData["SuccessMessage"] = "Caballo actualizado exitosamente.";
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
