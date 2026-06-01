using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IAlimentacionRepositorio
    {
        Task<IEnumerable<AlimentacionDTO>> ObtenerTodosAsync();
        Task<AlimentacionDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearAlimentacionAsync(AlimentacionDTO dto);
        Task<bool> ActualizarAlimentacionAsync(AlimentacionDTO dto);
        Task<bool> EliminarAlimentacionAsync(int id);
    }
}
