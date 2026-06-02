using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.EstablosMgt.Suministros
{
    public class CrearModel : PageModel
    {
        private readonly ISuministroRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(ISuministroRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public SuministroDTO Suministro { get; set; } = new();

        public List<ProveedorDTO> Proveedores { get; set; } = new();

        private async Task CargarListasAsync()
        {
            var proveedores = await _db.QueryAsync<ProveedorDTO>("SELECT id_proveedor AS IdProveedor, nombre AS Nombre FROM proveedor WHERE estado = 'Activo' ORDER BY nombre");
            Proveedores = proveedores.ToList();
        }

        public async Task OnGetAsync()
        {
            await CargarListasAsync();
            try
            {
                int maxId = await _db.ExecuteScalarAsync<int?>("SELECT MAX(id_suministro) FROM public.suministro") ?? 0;
                Suministro.Codigo = $"SUM-{(maxId + 1):D3}";
            }
            catch
            {
                Suministro.Codigo = "SUM-001";
            }
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid)
            {
                await CargarListasAsync();
                return Page();
            }

            try
            {
                await _repo.CrearSuministroAsync(Suministro);
                TempData["SuccessMessage"] = "Suministro creado exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                await CargarListasAsync();
                return Page();
            }
        }
    }
}
