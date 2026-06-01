using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Inscripciones
{
    public class IndexModel : PageModel
    {
        private readonly IInscripcionRepositorio _repo;

        public IndexModel(IInscripcionRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<InscripcionDTO> Inscripciones { get; set; } = new List<InscripcionDTO>();

        public async Task OnGetAsync()
        {
            Inscripciones = await _repo.ObtenerTodosAsync();
        }
    }
}
