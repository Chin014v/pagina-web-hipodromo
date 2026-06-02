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
            ModelState.Remove("Asignacion.IdCaballo");

            if (!ModelState.IsValid)
            {
                var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo ORDER BY codigo");
                Establos = establos.ToList();
                return Page();
            }

            try
            {
                bool success = await _repo.ActualizarAsignacionAsync(Asignacion);
                if (!success)
                {
                    TempData["ErrorMessage"] = "No se encontró la asignación especificada o no hubo cambios.";
                    var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo ORDER BY codigo");
                    Establos = establos.ToList();
                    return Page();
                }
                TempData["SuccessMessage"] = "Asignación actualizada exitosamente.";
                return RedirectToPage("./Index");
            }
            catch (Exception ex)
            {
                string message = ex.Message;
                if (message.Contains("uq_asignacion_caballo_activa") || message.Contains("23505"))
                {
                    message = "El caballo ya cuenta con una asignación activa en otro establo.";
                }
                else if (message.Contains("capacidad") || message.Contains("tope") || message.Contains("cupo") || message.Contains("lleno"))
                {
                    message = "El establo seleccionado ya se encuentra lleno y no tiene capacidad disponible.";
                }
                else if (message.Contains("mantenimiento"))
                {
                    message = "No se puede asignar un caballo a un establo en mantenimiento.";
                }
                TempData["ErrorMessage"] = $"Error al actualizar asignación: {message}";
                var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo ORDER BY codigo");
                Establos = establos.ToList();
                return Page();
            }
        }
    }
}
