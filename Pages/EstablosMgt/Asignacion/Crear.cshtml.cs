using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.EstablosMgt.Asignacion
{
    public class CrearModel : PageModel
    {
        private readonly IAsignacionEstabloRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IAsignacionEstabloRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public AsignacionEstabloDTO Asignacion { get; set; } = new();

        public List<CaballoDTO> Caballos { get; set; } = new();
        public List<EstabloDTO> Establos { get; set; } = new();

        public async Task OnGetAsync()
        {
            var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = caballos.ToList();

            var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo WHERE estado = 'Disponible' ORDER BY codigo");
            Establos = establos.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearAsignacionAsync(Asignacion);
                TempData["SuccessMessage"] = "Asignación creada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error al guardar: {ex.Message}";
                return Page();
            }
        }
    }
}
