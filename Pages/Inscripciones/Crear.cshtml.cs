using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Inscripciones
{
    [Authorize(Roles = "Administrador,Propietario")]
    public class CrearModel : PageModel
    {
        private readonly IInscripcionRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IInscripcionRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public InscripcionDTO Inscripcion { get; set; } = new();

        public List<EventoDTO> Eventos { get; set; } = new();
        public List<CaballoDTO> Caballos { get; set; } = new();

        private async Task CargarListasAsync()
        {
            var eventos = await _db.QueryAsync<EventoDTO>("SELECT id_evento AS IdEvento, codigo_evento AS CodigoEvento, nombre AS Nombre FROM evento WHERE estado IN ('Programado','EnCurso') ORDER BY nombre");
            Eventos = eventos.ToList();

            if (User.IsInRole("Propietario"))
            {
                var claim = User.FindFirst("PropietarioId");
                if (claim != null && int.TryParse(claim.Value, out int idProp))
                {
                    var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, codigo_unico AS CodigoUnico, nombre AS Nombre FROM caballo WHERE id_propietario = @IdProp ORDER BY nombre", new { IdProp = idProp });
                    Caballos = caballos.ToList();
                    return;
                }
            }

            var allCaballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, codigo_unico AS CodigoUnico, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = allCaballos.ToList();
        }

        public async Task OnGetAsync()
        {
            await CargarListasAsync();
            try
            {
                int maxId = await _db.ExecuteScalarAsync<int?>("SELECT MAX(id_inscripcion) FROM public.inscripcion") ?? 0;
                Inscripcion.CodigoInscripcion = $"INS-{(maxId + 1):D3}";
            }
            catch
            {
                Inscripcion.CodigoInscripcion = "INS-001";
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
                await _repo.CrearInscripcionAsync(Inscripcion);
                TempData["SuccessMessage"] = "Inscripción creada exitosamente.";
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
