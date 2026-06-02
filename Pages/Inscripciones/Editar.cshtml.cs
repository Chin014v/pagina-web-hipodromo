using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Inscripciones
{
    public class EditarModel : PageModel
    {
        private readonly IInscripcionRepositorio _repo;

        public EditarModel(IInscripcionRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public InscripcionDTO Inscripcion { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Inscripcion = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Inscripcion.CodigoInscripcion");
            ModelState.Remove("Inscripcion.IdEvento");
            ModelState.Remove("Inscripcion.IdCaballo");

            if (!ModelState.IsValid) return Page();

            try
            {
                bool success = await _repo.ActualizarInscripcionAsync(Inscripcion);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró la inscripción especificada o no hubo cambios.";
                    return Page();
                }
                TempData["SuccessMessage"] = "Inscripción actualizada exitosamente.";
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
