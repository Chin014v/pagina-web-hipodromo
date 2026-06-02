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

        private async Task CargarListasAsync()
        {
            var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = caballos.ToList();

            var establos = await _db.QueryAsync<EstabloDTO>("SELECT id_establo AS IdEstablo, codigo AS Codigo, ubicacion AS Ubicacion FROM establo WHERE estado = 'Disponible' ORDER BY codigo");
            Establos = establos.ToList();
        }

        public async Task OnGetAsync()
        {
            await CargarListasAsync();
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
                await _repo.CrearAsignacionAsync(Asignacion);
                TempData["SuccessMessage"] = "Asignación creada exitosamente.";
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
                TempData["ErrorMessage"] = $"Error al asignar establo: {message}";
                await CargarListasAsync();
                return Page();
            }
        }
    }
}
