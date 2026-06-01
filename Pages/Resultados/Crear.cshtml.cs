using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Resultados
{
    public class CrearModel : PageModel
    {
        private readonly IResultadoRepositorio _repo;
        private readonly IDbConnection _db;

        public CrearModel(IResultadoRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        [BindProperty]
        public ResultadoDTO Resultado { get; set; } = new();

        public List<InscripcionDTO> Inscripciones { get; set; } = new();

        public async Task OnGetAsync()
        {
            var list = await _db.QueryAsync<InscripcionDTO>(@"
                SELECT i.id_inscripcion AS IdInscripcion, c.nombre AS NombreCaballo, e.nombre AS NombreEvento
                FROM inscripcion i
                JOIN caballo c ON i.id_caballo = c.id_caballo
                JOIN evento e ON i.id_evento = e.id_evento
                WHERE i.estado = 'Aprobada'
                AND NOT EXISTS (SELECT 1 FROM resultado_carrera r WHERE r.id_inscripcion = i.id_inscripcion)
                ORDER BY e.nombre, c.nombre");
            Inscripciones = list.ToList();
        }

        public async Task<IActionResult> OnPostAsync()
        {
            if (!ModelState.IsValid) return Page();

            try
            {
                await _repo.CrearResultadoAsync(Resultado);
                TempData["SuccessMessage"] = "Resultado registrado exitosamente.";
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
