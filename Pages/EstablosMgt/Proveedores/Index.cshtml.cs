using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;

namespace HipodromoNacional.Pages.EstablosMgt.Proveedores
{
    public class IndexModel : PageModel
    {
        private readonly IProveedorRepositorio _repo;

        public IndexModel(IProveedorRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<ProveedorDTO> Proveedores { get; set; } = new List<ProveedorDTO>();

        public async Task OnGetAsync()
        {
            Proveedores = await _repo.ObtenerTodosAsync();
        }
    }
}
