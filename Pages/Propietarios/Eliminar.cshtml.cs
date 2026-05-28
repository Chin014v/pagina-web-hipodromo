using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Propietarios
{
    public class EliminarModel : PageModel
    {
        private readonly IPropietarioRepositorio _repo;

        public EliminarModel(IPropietarioRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public PropietarioDTO Propietario { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var p = await _repo.ObtenerPorIdAsync(id);
            if (p == null) return NotFound();

            Propietario = p;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarPropietarioAsync(Propietario.IdPropietario);
                TempData["SuccessMessage"] = "Propietario eliminado exitosamente.";
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
