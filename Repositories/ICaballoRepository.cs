using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public interface ICaballoRepository
    {
        Task<IEnumerable<CaballoDTO>> ObtenerTodosAsync();
        Task<CaballoDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearCaballoAsync(CaballoDTO caballo);
        Task<bool> ActualizarCaballoAsync(CaballoDTO caballo);
        Task<bool> EliminarCaballoAsync(int id);
    }
}
