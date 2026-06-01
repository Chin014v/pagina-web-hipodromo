using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using System.Data;
using Dapper;

namespace HipodromoNacional.Pages.Resultados
{
    public class IndexModel : PageModel
    {
        private readonly IResultadoRepositorio _repo;
        private readonly IDbConnection _db;

        public IndexModel(IResultadoRepositorio repo, IDbConnection db)
        {
            _repo = repo;
            _db = db;
        }

        public IEnumerable<ResultadoDTO> Resultados { get; set; } = new List<ResultadoDTO>();
        public List<EventoDTO> EventosFinalizados { get; set; } = new();

        public async Task OnGetAsync()
        {
            Resultados = await _repo.ObtenerTodosAsync();
            var eventos = await _db.QueryAsync<EventoDTO>("SELECT id_evento AS IdEvento, nombre AS Nombre FROM evento WHERE estado = 'Finalizado' ORDER BY nombre");
            EventosFinalizados = eventos.ToList();
        }

        public async Task<IActionResult> OnPostCalcularPremiosAsync(int idEvento)
        {
            try
            {
                await _repo.CalcularPremiosEventoAsync(idEvento);
                TempData["SuccessMessage"] = "Premios calculados exitosamente según distribución 50%-30%-20%.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = $"Error: {ex.Message}";
            }
            return RedirectToPage();
        }
    }
}
