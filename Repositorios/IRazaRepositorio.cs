using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IRazaRepositorio
    {
        Task<IEnumerable<RazaDTO>> ObtenerTodasAsync();
        Task<RazaDTO> ObtenerPorIdAsync(int id);
        Task<bool> CrearRazaAsync(RazaDTO r);
        Task<bool> ActualizarRazaAsync(RazaDTO r);
        Task<bool> EliminarRazaAsync(int id);
    }
}
