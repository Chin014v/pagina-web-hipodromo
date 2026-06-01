using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Alertas
{
    public class IndexModel : PageModel
    {
        private readonly IAlertaRepositorio _repo;

        public IndexModel(IAlertaRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<AlertaCertificacionDTO> Alertas { get; set; } = new List<AlertaCertificacionDTO>();

        public async Task OnGetAsync()
        {
            Alertas = await _repo.ObtenerTodosAsync();
        }
    }
}
