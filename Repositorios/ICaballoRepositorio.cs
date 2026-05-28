using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface ICaballoRepositorio
    {
        Task<IEnumerable<CaballoDTO>> ObtenerTodosAsync();
        Task<CaballoDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearCaballoAsync(CaballoDTO caballo);
        Task<bool> ActualizarCaballoAsync(CaballoDTO caballo);
        Task<bool> EliminarCaballoAsync(int id);
    }
}
