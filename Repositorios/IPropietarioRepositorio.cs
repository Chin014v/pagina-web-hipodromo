using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IPropietarioRepositorio
    {
        Task<IEnumerable<PropietarioDTO>> ObtenerTodosAsync();
        Task<PropietarioDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearPropietarioAsync(PropietarioDTO propietario, string[] telefonos, string[] tiposTelefonos, string[] correos, string[] tiposCorreos);
        Task<bool> ActualizarPropietarioAsync(PropietarioUpdateDTO propietario);
        Task<bool> EliminarPropietarioAsync(int id);
    }
}
