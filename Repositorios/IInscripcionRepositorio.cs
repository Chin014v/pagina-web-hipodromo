using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IInscripcionRepositorio
    {
        Task<IEnumerable<InscripcionDTO>> ObtenerTodosAsync();
        Task<InscripcionDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearInscripcionAsync(InscripcionDTO dto);
        Task<bool> ActualizarInscripcionAsync(InscripcionDTO dto);
        Task<bool> EliminarInscripcionAsync(int id);
    }
}
