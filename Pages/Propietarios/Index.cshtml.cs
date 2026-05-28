using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.Propietarios
{
    public class IndexModel : PageModel
    {
        private readonly IPropietarioRepositorio _repo;

        public IndexModel(IPropietarioRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<PropietarioDTO> Propietarios { get; set; } = new List<PropietarioDTO>();

        public async Task OnGetAsync()
        {
            Propietarios = await _repo.ObtenerTodosAsync();
        }
    }
}
