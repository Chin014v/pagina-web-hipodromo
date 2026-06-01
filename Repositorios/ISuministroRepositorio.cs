using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface ISuministroRepositorio
    {
        Task<IEnumerable<SuministroDTO>> ObtenerTodosAsync();
        Task<SuministroDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearSuministroAsync(SuministroDTO dto);
        Task<bool> ActualizarSuministroAsync(SuministroDTO dto);
        Task<bool> EliminarSuministroAsync(int id);
    }
}
