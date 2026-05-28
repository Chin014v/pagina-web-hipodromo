using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IEstabloRepositorio
    {
        Task<IEnumerable<EstabloDTO>> ObtenerTodosAsync();
        Task<EstabloDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearEstabloAsync(EstabloDTO establo);
        Task<bool> ActualizarEstabloAsync(EstabloDTO establo);
        Task<bool> EliminarEstabloAsync(int id);
    }
}
