using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Resultados
{
    public class EditarModel : PageModel
    {
        private readonly IResultadoRepositorio _repo;

        public EditarModel(IResultadoRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public ResultadoDTO Resultado { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Resultado = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            ModelState.Remove("Resultado.IdInscripcion");
            ModelState.Remove("Resultado.TiempoRegistro");
            ModelState.Remove("Resultado.FechaRegistro");
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.ActualizarResultadoAsync(Resultado);
                TempData["SuccessMessage"] = "Resultado actualizado exitosamente.";
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
