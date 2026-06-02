using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Suministros
{
    public class EditarModel : PageModel
    {
        private readonly ISuministroRepositorio _repo;

        public EditarModel(ISuministroRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public SuministroDTO Suministro { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Suministro = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Suministro.Codigo");
            ModelState.Remove("Suministro.NombreSuministro");
            ModelState.Remove("Suministro.Tipo");
            ModelState.Remove("Suministro.IdProveedor");
            ModelState.Remove("Suministro.UnidadMedida");

            if (!ModelState.IsValid) return Page();

            try
            {
                bool success = await _repo.ActualizarSuministroAsync(Suministro);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el suministro especificado o no hubo cambios.";
                    return Page();
                }
                TempData["SuccessMessage"] = "Suministro actualizado exitosamente.";
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
