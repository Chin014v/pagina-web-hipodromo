using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IAsignacionEstabloRepositorio
    {
        Task<IEnumerable<AsignacionEstabloDTO>> ObtenerTodosAsync();
        Task<AsignacionEstabloDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearAsignacionAsync(AsignacionEstabloDTO dto);
        Task<bool> ActualizarAsignacionAsync(AsignacionEstabloDTO dto);
        Task<bool> EliminarAsignacionAsync(int id);
    }
}
