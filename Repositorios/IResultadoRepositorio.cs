using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IResultadoRepositorio
    {
        Task<IEnumerable<ResultadoDTO>> ObtenerTodosAsync();
        Task<ResultadoDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearResultadoAsync(ResultadoDTO dto);
        Task<bool> ActualizarResultadoAsync(ResultadoDTO dto);
        Task<bool> EliminarResultadoAsync(int id);
        Task<bool> CalcularPremiosEventoAsync(int idEvento);
    }
}
