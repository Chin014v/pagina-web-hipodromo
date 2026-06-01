using Microsoft.AspNetCore.Mvc.RazorPages;
using HipodromoNacional.Modelos;
using HipodromoNacional.Repositorios;
using Microsoft.AspNetCore.Authorization;

namespace HipodromoNacional.Pages.Usuarios
{
    [Authorize(Roles = "Administrador")]
    public class IndexModel : PageModel
    {
        private readonly IUsuarioRepositorio _repo;

        public IndexModel(IUsuarioRepositorio repo)
        {
            _repo = repo;
        }

        public IEnumerable<UsuarioDTO> Usuarios { get; set; } = new List<UsuarioDTO>();

        public async Task OnGetAsync()
        {
            Usuarios = await _repo.ObtenerTodosAsync();
        }
    }
}
