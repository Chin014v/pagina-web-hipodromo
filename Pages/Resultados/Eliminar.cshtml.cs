using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Resultados
{
    public class EliminarModel : PageModel
    {
        private readonly IResultadoRepositorio _repo;

        public EliminarModel(IResultadoRepositorio repo)
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
            try
            {
                await _repo.EliminarResultadoAsync(Resultado.IdResultado);
                TempData["SuccessMessage"] = "Resultado eliminado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al eliminar: {ex.Message}";
                return RedirectToPage("./Index");
            }
        }
    }
}
