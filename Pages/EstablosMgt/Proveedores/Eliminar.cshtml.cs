using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Proveedores
{
    public class EliminarModel : PageModel
    {
        private readonly IProveedorRepositorio _repo;

        public EliminarModel(IProveedorRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public ProveedorDTO Proveedor { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Proveedor = item;
            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.EliminarProveedorAsync(Proveedor.IdProveedor);
                TempData["SuccessMessage"] = "Proveedor eliminado exitosamente.";
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
