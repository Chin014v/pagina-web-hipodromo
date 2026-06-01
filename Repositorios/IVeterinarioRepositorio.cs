using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IVeterinarioRepositorio
    {
        Task<IEnumerable<HistorialVeterinarioDTO>> ObtenerTodosAsync();
        Task<HistorialVeterinarioDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearHistorialAsync(HistorialVeterinarioDTO dto);
        Task<bool> ActualizarHistorialAsync(HistorialVeterinarioDTO dto);
        Task<bool> EliminarHistorialAsync(int id);
    }
}
