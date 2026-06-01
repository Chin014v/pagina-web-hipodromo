using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Suministros
{
    public class EliminarModel : PageModel
    {
        private readonly ISuministroRepositorio _repo;

        public EliminarModel(ISuministroRepositorio repo)
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
            try
            {
                await _repo.EliminarSuministroAsync(Suministro.IdSuministro);
                TempData["SuccessMessage"] = "Suministro eliminado exitosamente.";
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
