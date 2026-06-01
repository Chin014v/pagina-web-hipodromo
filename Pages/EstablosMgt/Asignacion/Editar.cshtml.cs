using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.EstablosMgt.Asignacion
{
    public class EditarModel : PageModel
    {
        private readonly IAsignacionEstabloRepositorio _repo;
        private readonly IDbConnection _db;

        public EditarModel(IAsignacionEstabloRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public AsignacionEstabloDTO Asignacion { get; set; } = new();

        public List<EstabloDTO> Establos { get; set; } = new();

        public async Task<IActionResult> OnGetAsync(int id)
        {
            var item = await _repo.ObtenerPorIdAsync(id);
            if (item == null) return NotFound();

            Asignacion = item;

            var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo ORDER BY codigo");
            Establos = establos.ToList();

            return Page();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            try
            {
                await _repo.ActualizarAsignacionAsync(Asignacion);
                TempData["SuccessMessage"] = "Asignación actualizada exitosamente.";
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
