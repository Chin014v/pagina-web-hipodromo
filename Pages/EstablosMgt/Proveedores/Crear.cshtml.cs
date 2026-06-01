using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Proveedores
{
    public class CrearModel : PageModel
    {
        private readonly IProveedorRepositorio _repo;

        public CrearModel(IProveedorRepositorio repo)
        {
            _repo = repo;
        }

        [BindProperty]
        public ProveedorDTO Proveedor { get; set; } = new();

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearProveedorAsync(Proveedor);
                TempData["SuccessMessage"] = "Proveedor creado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                return Page();
            }
        }

        public void OnGet() { }
    }
}
