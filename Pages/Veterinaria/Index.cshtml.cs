using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Veterinaria
{
    public class IndexModel : PageModel
    {
        private readonly IVeterinarioRepositorio _repo;

        public IndexModel(IVeterinarioRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<HistorialVeterinarioDTO> Historiales { get; set; } = new List<HistorialVeterinarioDTO>();

        public async Task OnGetAsync()
        {
            Historiales = await _repo.ObtenerTodosAsync();
        }
    }
}
