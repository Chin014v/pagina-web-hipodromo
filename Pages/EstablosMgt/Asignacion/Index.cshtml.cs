using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Asignacion
{
    public class IndexModel : PageModel
    {
        private readonly IAsignacionEstabloRepositorio _repo;

        public IndexModel(IAsignacionEstabloRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<AsignacionEstabloDTO> Asignaciones { get; set; } = new List<AsignacionEstabloDTO>();

        public async Task OnGetAsync()
        {
            Asignaciones = await _repo.ObtenerTodosAsync();
        }
    }
}
