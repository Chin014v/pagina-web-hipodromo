using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public interface IPropietarioRepository
    {
        Task<int> CrearPropietarioAsync(PropietarioDTO propietario, string[] telefonos, string[] tiposTelefonos, string[] correos, string[] tiposCorreos);
        Task<bool> ActualizarPropietarioAsync(PropietarioUpdateDTO propietario);
        Task<bool> EliminarPropietarioAsync(int id);
    }
}
