using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Proveedores
{
    public class EditarModel : PageModel
    {
        private readonly IProveedorRepositorio _repo;

        public EditarModel(IProveedorRepositorio repo)
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
            ModelState.Remove("Proveedor.Nombre");

            if (!ModelState.IsValid) return Page();

            try
            {
                bool success = await _repo.ActualizarProveedorAsync(Proveedor);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró el proveedor especificado o no hubo cambios.";
                    return Page();
                }
                TempData["SuccessMessage"] = "Proveedor actualizado exitosamente.";
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
