using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public interface IEstabloRepository
    {
        Task<IEnumerable<EstabloDTO>> ObtenerTodosAsync();
        Task<EstabloDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearEstabloAsync(EstabloDTO establo);
        Task<bool> ActualizarEstabloAsync(EstabloDTO establo);
        Task<bool> EliminarEstabloAsync(int id);
    }
}
