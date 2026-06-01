using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IUsuarioRepositorio
    {
        Task<IEnumerable<UsuarioDTO>> ObtenerTodosAsync();
        Task<UsuarioDTO> ObtenerPorIdAsync(int id);
        Task<bool> CrearUsuarioAsync(UsuarioDTO u);
        Task<bool> ActualizarUsuarioAsync(UsuarioDTO u);
        Task<bool> EliminarUsuarioAsync(int id);
        Task<UsuarioDTO?> ValidarUsuarioAsync(string username, string password);
        Task<IEnumerable<RolDTO>> ObtenerRolesAsync();
    }
}
