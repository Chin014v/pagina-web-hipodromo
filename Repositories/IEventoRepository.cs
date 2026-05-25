using HipodromoNacional.Models;

namespace HipodromoNacional.Repositories
{
    public interface IEventoRepository
    {
        Task<IEnumerable<EventoDTO>> ObtenerTodosAsync();
        Task<EventoDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearEventoAsync(EventoDTO evento);
        Task<bool> ActualizarEventoAsync(EventoDTO evento);
        Task<bool> EliminarEventoAsync(int id);
    }
}
