using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Inscripciones
{
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

        public async Task OnGetAsync()
        {
            var eventos = await _db.QueryAsync<EventoDTO>("SELECT id_evento AS IdEvento, codigo_evento AS CodigoEvento, nombre AS Nombre FROM evento WHERE estado IN ('Programado','EnCurso') ORDER BY nombre");
            Eventos = eventos.ToList();

            var caballos = await _db.QueryAsync<CaballoDTO>("SELECT id_caballo AS IdCaballo, codigo_unico AS CodigoUnico, nombre AS Nombre FROM caballo ORDER BY nombre");
            Caballos = caballos.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearInscripcionAsync(Inscripcion);
                TempData["SuccessMessage"] = "Inscripción creada exitosamente.";
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
