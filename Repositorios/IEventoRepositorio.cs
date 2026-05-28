using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IEventoRepositorio
    {
        Task<IEnumerable<EventoDTO>> ObtenerTodosAsync();
        Task<EventoDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearEventoAsync(EventoDTO evento);
        Task<bool> ActualizarEventoAsync(EventoDTO evento);
        Task<bool> EliminarEventoAsync(int id);
    }
}
