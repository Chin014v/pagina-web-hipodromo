using HipodromoNacional.Modelos;

namespace HipodromoNacional.Repositorios
{
    public interface IBeneficioRepositorio
    {
        Task<IEnumerable<BeneficioPropietarioDTO>> ObtenerTodosAsync();
        Task<BeneficioPropietarioDTO> ObtenerPorIdAsync(int id);
        Task<int> CrearBeneficioAsync(BeneficioPropietarioDTO dto);
        Task<bool> ActualizarBeneficioAsync(BeneficioPropietarioDTO dto);
        Task<bool> EliminarBeneficioAsync(int id);
    }
}
