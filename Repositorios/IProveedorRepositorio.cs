using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IProveedorRepositorio
    {
        Task<IEnumerable<ProveedorDTO>> ObtenerTodosAsync();
        Task<ProveedorDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearProveedorAsync(ProveedorDTO dto);
        Task<bool> ActualizarProveedorAsync(ProveedorDTO dto);
        Task<bool> EliminarProveedorAsync(int id);
    }
}
